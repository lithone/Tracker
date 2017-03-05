//
//  SpotDataRetreiver.swift
//  Tracker
//
//  Created by Warren Kadosh on 2016-12-31.
//  Copyright © 2016 Warren Kadosh. All rights reserved.
//

import Foundation
import CoreData
import UIKit

enum DataRetreiveOperation: Equatable {
    case retreiveAll
    case retreiveFromMessageIndex(Int)
    case retreiveFromMessageTime(Date)
    case retreiveFromMessageTimeAndIndex(Date, Int)
    
    static func ==(lhs: DataRetreiveOperation, rhs: DataRetreiveOperation) -> Bool {
        switch (lhs, rhs) {
        case (.retreiveAll, .retreiveAll):
            return true
        case (let .retreiveFromMessageTime(lhsTime), let .retreiveFromMessageTime(rhsTime)):
            if lhsTime == rhsTime {
                return true
            }
        case (let .retreiveFromMessageIndex(lhsIndex), let .retreiveFromMessageIndex(rhsIndex)):
            if lhsIndex == rhsIndex {
                return true
            }
        default:
            return false
        }
        return false
    }
}

struct DataRetreiveOperationQueue {
    var array = Array<DataRetreiveOperation>()
    
    var isEmpty: Bool {
        return array.isEmpty
    }
    
    mutating func enqueue(_ element: DataRetreiveOperation) {
        array.append(element)
    }
    
    mutating func dequeue() -> DataRetreiveOperation? {
        guard !array.isEmpty, let element = array.first else { return nil }
        
        array.remove(at: 0)
        
        return element
    }
    
    mutating func clear() {
        array.removeAll()
    }
    
    func peek() -> DataRetreiveOperation? {
        return array.first
    }
    
    func contains(dataRetreiveOperation: DataRetreiveOperation) -> Bool {
        return array.contains() { $0 == dataRetreiveOperation
        }
    }
}

struct SpotLoginInfo {
    var feedId: String?
    var feedPassword: String?
    var minRefreshSeconds: Double = 150.0
    var idleRefreshSeconds: Double = 300.0
    var lastRefreshTime: Date?
 
    
    func getFeedURL(fromTime: Date? = nil, toTime: Date? = nil, messageIndexStart: Int? = nil) -> String? {
        guard feedId != nil else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss-0000"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let fromTimeParameter = fromTime != nil ? "startDate=" + dateFormatter.string(from: fromTime!) + "&" : ""
        let toTimeParameter = toTime != nil ? "endDate=" + dateFormatter.string(from: toTime!) + "&" : ""
        let messageIndexStartParameter = messageIndexStart != nil ? "start=\(messageIndexStart)&" : ""
        return "https://api.findmespot.com/spot-main-web/consumer/rest-api/2.0/public/feed/\(feedId!)/message.xml?" + fromTimeParameter + toTimeParameter + messageIndexStartParameter + (feedPassword != nil ? "feedPassword=" + feedPassword! : "")
    }
}

class SpotDataRetreiver: NSObject, XMLParserDelegate, URLSessionDownloadDelegate {
    private var dataRetreiveOperationQueue = DataRetreiveOperationQueue()
    private var refreshTimer: Timer?
    private var refreshTimerFiredOnce = false
    private var refreshTimerNeedsProperInterval = true
    private var currentTrackMessage: TrackMessage?
    private var currentTrackMessageChain: TrackMessageChain?
    private var pageMessageCount = 0
    private var XMLBuffer: String = ""
    var downloadTask: URLSessionDownloadTask!
    var backgroundSession: URLSession!
    var backgroundFetchCompletionHandler: ((UIBackgroundFetchResult) -> Void)?


    var loginInfo = SpotLoginInfo()
    var managedObjectContext: NSManagedObjectContext?
    
    init(feedId: String, feedPassword: String, context: NSManagedObjectContext) {
        super.init()
        
        // Initialize login parameters and CoreData.
        loginInfo.feedId = feedId
        loginInfo.feedPassword = feedPassword
        managedObjectContext = context
    }
    
    func orderMessageRefresh(forceRefreshAll: Bool = false) {
        // If there is no recorded last message time, order a full refresh paging through all the data. Otherwise, order a refresh since the last message time (unless a forceRefreshAll was requested).
        
        // Clear all pending refresh operations. 
        dataRetreiveOperationQueue.clear()
        
        // Get the last message time.
        var lastMessageTime: Date? = nil
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "TrackMessage")
        request.fetchLimit = 1
        let sort = NSSortDescriptor(key: "time", ascending: false)
        request.sortDescriptors = [sort]
        do {
            let results = try managedObjectContext?.fetch(request) as! [TrackMessage]
            if results.count > 0 {
                lastMessageTime = results.first?.time as Date?
                print("Last message time \(lastMessageTime)")
            }
        } catch let error {
            print("Unable to get last message time. \(error.localizedDescription)")
        }
        var lastMessageTimeWithOffset: Date?
        if lastMessageTime != nil {
            lastMessageTimeWithOffset = Calendar.current.date(byAdding: .second, value: -1, to: lastMessageTime!)
        }
        if lastMessageTimeWithOffset != nil, !dataRetreiveOperationQueue.contains(dataRetreiveOperation: .retreiveAll), !forceRefreshAll {
            let dataRetreiveOperationWithOffset = DataRetreiveOperation.retreiveFromMessageTime(lastMessageTimeWithOffset!)
            if !dataRetreiveOperationQueue.contains(dataRetreiveOperation: dataRetreiveOperationWithOffset) {
                dataRetreiveOperationQueue.enqueue(dataRetreiveOperationWithOffset)
            }
        } else {
            if !dataRetreiveOperationQueue.contains(dataRetreiveOperation: .retreiveAll) {
                dataRetreiveOperationQueue.enqueue(.retreiveAll)
            }
        }
    }

    func resumeMessageRefreshing() {
        print("Resuming message refresh \(Date())")
        let userDefaults = UserDefaults.standard
        if let lastRefreshTime = userDefaults.object(forKey: "LastRefreshTime") as? Date {
            // Set the timer to fire at the next allowble interval, measured from the last time it fired.
            // If the timer never fired, it can be set with the proper minimum interval and fired for the first time immediately. If it has fired, it must be ensured that a sufficient interval has passed before firing it again.
            print("last refresh time \(lastRefreshTime)")
            let nextAllowableInterval: Double = (Calendar.current.date(byAdding: .second, value: Int(loginInfo.minRefreshSeconds), to: lastRefreshTime)!.timeIntervalSince(Date())) as Double
            print("time \(Date()), next interval \(nextAllowableInterval)")
            print("nextAllowableInterval \(nextAllowableInterval)")
            if nextAllowableInterval < 0 {
                refreshTimerNeedsProperInterval = false
                createRefreshTimer(interval: loginInfo.minRefreshSeconds, repeats: true)
                refreshTimer?.fire()
            } else {
                createRefreshTimer(interval: nextAllowableInterval, repeats: false)
                refreshTimerNeedsProperInterval = true
            }
        } else {
            refreshTimerNeedsProperInterval = false
            createRefreshTimer(interval: loginInfo.minRefreshSeconds, repeats: true)
            refreshTimer?.fire()
        }
    }
    
    func pauseMessageRefreshing() {
        print("Pausing message refresh \(Date())")
        refreshTimer?.invalidate()
        //refreshTimer = nil
    }
    
    private func createRefreshTimer(interval: Double, repeats: Bool) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { _ in
            let queue = DispatchQueue(label: "SpotDataRetreiver", qos: .userInitiated)
            queue.async {
                print("Timer fired at \(Date())")
                if self.refreshTimerNeedsProperInterval {
                    self.createRefreshTimer(interval: self.loginInfo.minRefreshSeconds, repeats: true)
                    self.refreshTimerNeedsProperInterval = false
                }
                if let operationToExecute = self.dataRetreiveOperationQueue.peek() {
                    print("refresh timer fired at \(Date()) with \(operationToExecute)")
                    switch operationToExecute {
                    case .retreiveAll:
                        // Get the first 50 messages. If 50 messages are returned, there may be more, so fetch the next batch of 50.
                        if let feedUrlFull = self.loginInfo.getFeedURL() {
                            print(feedUrlFull)
                            if let url = URL(string: feedUrlFull) {
                                self.loginInfo.lastRefreshTime = Date()
                                self.downloadData(url: url)
                                _ = self.dataRetreiveOperationQueue.dequeue()
                                UserDefaults.standard.set(Date(), forKey: "LastRefreshTime")
                                if self.pageMessageCount == 50 {
                                    self.dataRetreiveOperationQueue.enqueue(.retreiveFromMessageIndex(51))
                                } else {
                                    self.orderMessageRefresh()
                                }
                            }
                        }
                    case let .retreiveFromMessageIndex(messageIndex): 
                        // Get the first 50 messages starting from messageIndex. If 50 messages are returned, there may be more, so fetch the next batch of 50.
                        if let feedUrlFull = self.loginInfo.getFeedURL(fromTime: nil, toTime: nil, messageIndexStart: messageIndex) {
                            print(feedUrlFull)
                            if let url = URL(string: feedUrlFull) {
                                self.loginInfo.lastRefreshTime = Date()
                                self.downloadData(url: url)
                                _ = self.dataRetreiveOperationQueue.dequeue()
                                UserDefaults.standard.set(Date(), forKey: "LastRefreshTime")
                                if self.pageMessageCount == 50 {
                                    self.dataRetreiveOperationQueue.enqueue(.retreiveFromMessageIndex(messageIndex + 50))
                                } else {
                                    self.orderMessageRefresh()
                                }
                            }
                        }
                    case let .retreiveFromMessageTime(messageTime):
                        // Get the first 50 messages starting from messageTime. If 50 messages are returned, there may be more, so fetch the next batch of 50.
                        if let feedUrlFull = self.loginInfo.getFeedURL(fromTime: messageTime, toTime: nil, messageIndexStart: nil) {
                            print(feedUrlFull)
                            if let url = URL(string: feedUrlFull) {
                                self.loginInfo.lastRefreshTime = Date()
                                self.downloadData(url: url)
                                _ = self.dataRetreiveOperationQueue.dequeue()
                                UserDefaults.standard.set(Date(), forKey: "LastRefreshTime")
                                if self.pageMessageCount == 50 {
                                    self.dataRetreiveOperationQueue.enqueue(.retreiveFromMessageTimeAndIndex(messageTime, 51))
                                } else {
                                    self.orderMessageRefresh()
                                }
                            }
                        }
                    case let .retreiveFromMessageTimeAndIndex(messageTime, messageIndex):
                        // Get the first 50 messages starting from messageTime and messageIndex. If 50 messages are returned, there may be more, so fetch the next batch of 50.
                        if let feedUrlFull = self.loginInfo.getFeedURL(fromTime: messageTime, toTime: nil, messageIndexStart: messageIndex) {
                            print(feedUrlFull)
                            if let url = URL(string: feedUrlFull) {
                                self.loginInfo.lastRefreshTime = Date()
                                self.downloadData(url: url)
                                _ = self.dataRetreiveOperationQueue.dequeue()
                                UserDefaults.standard.set(Date(), forKey: "LastRefreshTime")
                                if self.pageMessageCount == 50 {
                                    self.dataRetreiveOperationQueue.enqueue(.retreiveFromMessageTimeAndIndex(messageTime, messageIndex + 50))
                                } else {
                                    self.orderMessageRefresh()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func downloadData(url: URL) {
        let backgroundSessionConfiguration = URLSessionConfiguration.background(withIdentifier: "SpotDataRetreiver")
        backgroundSession = URLSession(configuration: backgroundSessionConfiguration, delegate: self, delegateQueue: nil)
        downloadTask = backgroundSession.downloadTask(with: url)
        downloadTask.resume()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let xmlParser = XMLParser(contentsOf: location) {
            xmlParser.delegate = self
            _ = xmlParser.parse()
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("didCompleteWithError \(Date())")
        backgroundSession.finishTasksAndInvalidate()
        if backgroundFetchCompletionHandler != nil {
            backgroundFetchCompletionHandler!(UIBackgroundFetchResult.newData)
            backgroundFetchCompletionHandler = nil
        }
    }
    
    func parserDidStartDocument(_ parser: XMLParser) {
        pageMessageCount = 0
        print("start of XML \(Date())")
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        do {
            try managedObjectContext?.save()
            print("Saved")
        } catch _ {
            print("Unable to save refresh objects to CoreData. ")
        }
        print("End of XML \(Date())")
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        XMLBuffer = ""
        switch elementName {
        case "message":
            // Create a new TrackMessage.
            if managedObjectContext != nil {
                let entity = NSEntityDescription.entity(forEntityName: "TrackMessage", in: managedObjectContext!)
                currentTrackMessage = NSManagedObject(entity: entity!, insertInto: managedObjectContext) as? TrackMessage
            }
        default: break
        }
        print("Start of \(elementName)")
        
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "message":
            // Save the completed message if it does not already exist, otherwise, discard it. 
            
            guard currentTrackMessage?.id != nil else {
                currentTrackMessage = nil
                return
            }
            
            let request: NSFetchRequest<TrackMessage> = TrackMessage.fetchRequest()
            request.predicate = NSPredicate(format: "id == %d", (currentTrackMessage?.id)!)
            if let results = try? managedObjectContext?.fetch(request) {
                if (results?.count) == 0 {
                    do {
                        try managedObjectContext?.save()
                        print("Saved")
                    } catch let error {
                        print("Save error \(error)")
                    }
                }
            }

            pageMessageCount += 1
            currentTrackMessage = nil
        case "id":
            let id = Int64(XMLBuffer)
            currentTrackMessage?.setValue(id, forKey: "id")
        case "messengerId":
            let senderId = XMLBuffer.isEmpty ? nil : XMLBuffer as String?
            currentTrackMessage?.setValue(senderId, forKey: "senderId")
        case "messengerName":
            let senderName = XMLBuffer.isEmpty ? nil : XMLBuffer as String?
            currentTrackMessage?.setValue(senderName, forKey: "senderName")
        case "messageType":
            if let type = TrackMessage.MessageType(rawValue: XMLBuffer) {
                let t = "\(type)"
                currentTrackMessage?.setValue(t, forKey: "type")
            }
        case "latitude":
            let latitude = Double(XMLBuffer)
            currentTrackMessage?.setValue(latitude, forKey: "latitude")
        case "longitude":
            let longitude = Double(XMLBuffer)
            currentTrackMessage?.setValue(longitude, forKey: "longitude")
        case "dateTime":
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            let time = dateFormatter.date(from: XMLBuffer)
            currentTrackMessage?.setValue(time, forKey: "time")
        case "batteryState":
            if let batteryState = TrackMessage.BatteryState(rawValue: XMLBuffer) {
                let bs = "\(batteryState)"
                currentTrackMessage?.setValue(bs, forKey: "batteryState")
            }
        default: break
        }
        
        print("\(XMLBuffer)")
        print("End of \(elementName)")
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        XMLBuffer += string
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didReceive data: Data) {
        
    }
}

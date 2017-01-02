//
//  SpotDataRetreiver.swift
//  Tracker
//
//  Created by Warren Kadosh on 2016-12-31.
//  Copyright © 2016 Warren Kadosh. All rights reserved.
//

import Foundation
import CoreData

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
    
    func peek() -> DataRetreiveOperation? {
        return array.first
    }
    
    func contains(dataRetreiveOperation: DataRetreiveOperation) -> Bool {
        return array.contains() { $0 == dataRetreiveOperation
        }
    }
}

struct SpotLoginInfo {
    var feedID: String?
    var feedPassword: String?
    
    func getFeedURL(fromTime: Date? = nil, toTime: Date? = nil, messageIndexStart: Int? = nil) -> String? {
        guard feedID != nil else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss-0000"
        //        let fromTimeParameter = fromTime != nil ? "startDate=" + dateFormatter.string(from: fromTime!) + "&" : ""
        let fromTimeParameter = "" //todo
        let toTimeParameter = toTime != nil ? "endDate=" + dateFormatter.string(from: toTime!) + "&" : ""
        let messageIndexStartParameter = messageIndexStart != nil ? "start=\(messageIndexStart)&" : ""
        return "https://api.findmespot.com/spot-main-web/consumer/rest-api/2.0/public/feed/\(feedID!)/message.xml?" + fromTimeParameter + toTimeParameter + messageIndexStartParameter + (feedPassword != nil ? "feedPassword=" + feedPassword! : "")
    }
}

class SpotDataRetreiver: NSObject, XMLParserDelegate {
    var loginInfo = SpotLoginInfo()
    var managedObjectContext: NSManagedObjectContext?
    private var lastMessageTime: Date?
    private var dataRetreiveOperationQueue = DataRetreiveOperationQueue()
    private var refreshTimer: Timer?
    private var refreshTimerFiredOnce = false
    private var currentTrackMessage: TrackMessage?
    private var currentTrackMessageChain: TrackMessageChain?
    private var pageMessageCount = 0
    
    func refreshData(forceRefreshAll: Bool = false) {
        // If there is no recorded last message time, do a full refresh paging through all the data. Otherwise, refresh since the last message time (unless a forceRefreshAll was requested).
        let userDefaults = UserDefaults.standard
        var lastMessageTimeWithOffset: Date?
        if let lastMessageTime = userDefaults.object(forKey: "LastMessageTime") as? Date {
            lastMessageTimeWithOffset = Calendar.current.date(byAdding: .second, value: -1, to: lastMessageTime)
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
        if !refreshTimerFiredOnce {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 150, repeats: true) { _ in
                let queue = DispatchQueue(label: "DataRetreiveQueue", qos: .userInitiated)
                queue.async {
                    self.executeDataRetreiveOperation()
                }
            }
            refreshTimer?.fire()
            refreshTimerFiredOnce = true
        }
    }
    
    func executeDataRetreiveOperation() {
        if let operationToExecute = dataRetreiveOperationQueue.dequeue() {
            print("refresh timer fired at \(Date()) with \(operationToExecute)")
            switch operationToExecute {
            case .retreiveAll:
                // Get first 50 messages. If 50 messages are returned, there may be more, so fetch the next batch of 50.
                if let feedUrlFull = loginInfo.getFeedURL() {
                    print(feedUrlFull)
                    if let url = URL(string: feedUrlFull) {
                        if let xmlParser = XMLParser(contentsOf: url) {
                            xmlParser.delegate = self
                            xmlParser.parse()
                            if pageMessageCount == 50 {
                                dataRetreiveOperationQueue.enqueue(.retreiveFromMessageIndex(51))
                            }
                        }
                    }
                }
            case let .retreiveFromMessageIndex(messageIndex):
                // Get 50 messages starting from messageIndex. If 50 messages are returned, there may be more, so fetch the next batch of 50.
                if let feedUrlFull = loginInfo.getFeedURL(fromTime: nil, toTime: nil, messageIndexStart: messageIndex) {
                    print(feedUrlFull)
                    if let url = URL(string: feedUrlFull) {
                        if let xmlParser = XMLParser(contentsOf: url) {
                            xmlParser.delegate = self
                            xmlParser.parse()
                            if pageMessageCount == 50 {
                                dataRetreiveOperationQueue.enqueue(.retreiveFromMessageIndex(messageIndex + 50))
                            }
                        }
                    }
                }
            case let .retreiveFromMessageTime(messageTime):
                if let feedUrlFull = loginInfo.getFeedURL(fromTime: messageTime, toTime: nil, messageIndexStart: nil) {
                    print(feedUrlFull)
                    if let url = URL(string: feedUrlFull) {
                        if let xmlParser = XMLParser(contentsOf: url) {
                            xmlParser.delegate = self
                            xmlParser.parse()
                            if pageMessageCount == 50 {
                                dataRetreiveOperationQueue.enqueue(.retreiveFromMessageTimeAndIndex(messageTime, 51))
                            }
                        }
                    }
                }
            case let .retreiveFromMessageTimeAndIndex(messageTime, messageIndex):
                if let feedUrlFull = loginInfo.getFeedURL(fromTime: messageTime, toTime: nil, messageIndexStart: messageIndex) {
                    print(feedUrlFull)
                    if let url = URL(string: feedUrlFull) {
                        if let xmlParser = XMLParser(contentsOf: url) {
                            xmlParser.delegate = self
                            xmlParser.parse()
                            if pageMessageCount == 50 {
                                dataRetreiveOperationQueue.enqueue(.retreiveFromMessageTimeAndIndex(messageTime, messageIndex + 50))
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var buffer: String = ""
    
    func parserDidStartDocument(_ parser: XMLParser) {
        pageMessageCount = 0
        print("start of XML")
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        do {
            try managedObjectContext?.save()
            print("Saved")
        } catch let error {
            
        }
        print("End of XML")
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        buffer = ""
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
            let id = Int64(buffer)
            currentTrackMessage?.setValue(id, forKey: "id")
        case "messengerId":
            let senderId = buffer.isEmpty ? nil : buffer as String?
            currentTrackMessage?.setValue(senderId, forKey: "senderId")
        case "messengerName":
            let senderName = buffer.isEmpty ? nil : buffer as String?
            currentTrackMessage?.setValue(senderName, forKey: "senderName")
        case "messageType":
            if let type = TrackMessage.MessageType(rawValue: buffer) {
                let t = "\(type)"
                currentTrackMessage?.setValue(t, forKey: "type")
            }
        case "latitude":
            let latitude = Double(buffer)
            currentTrackMessage?.setValue(latitude, forKey: "latitude")
        case "longitude":
            let longitude = Double(buffer)
            currentTrackMessage?.setValue(longitude, forKey: "longitude")
        case "dateTime":
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            let time = dateFormatter.date(from: buffer)
            currentTrackMessage?.setValue(time, forKey: "time")
        case "batteryState":
            if let batteryState = TrackMessage.BatteryState(rawValue: buffer) {
                let bs = "\(batteryState)"
                currentTrackMessage?.setValue(bs, forKey: "batteryState")
            }
        default: break
        }
        
        print("\(buffer)")
        print("End of \(elementName)")
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }
}

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
    case retreiveFromTime(Date)
    case retreiveFromMessageIndex(Int)
    
    static func ==(lhs: DataRetreiveOperation, rhs: DataRetreiveOperation) -> Bool {
        switch (lhs, rhs) {
        case (.retreiveAll, .retreiveAll):
            return true
        case (let .retreiveFromTime(lhsTime), let .retreiveFromTime(rhsTime)):
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
    
    func getFeedURL(fromTime: Date?, toTime: Date?, messageIndexStart: Int?) -> String? {
        guard feedID != nil else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss-0000"
        //        let fromTimeParameter = fromTime != nil ? "startDate=" + dateFormatter.string(from: fromTime!) + "&" : ""
        let fromTimeParameter = "" //todo
        let toTimeParameter = toTime != nil ? "endDate=" + dateFormatter.string(from: toTime!) + "&" : ""
        let messageIndexStartParameter = messageIndexStart != nil ? "start=\(messageIndexStart)&" : ""
        print("https://api.findmespot.com/spot-main-web/consumer/rest-api/2.0/public/feed/\(feedID!)/message.xml?" + fromTimeParameter + toTimeParameter + messageIndexStartParameter + (feedPassword != nil ? "feedPassword=" + feedPassword! : ""))
        return "https://api.findmespot.com/spot-main-web/consumer/rest-api/2.0/public/feed/\(feedID!)/message.xml?" + fromTimeParameter + toTimeParameter + messageIndexStartParameter + (feedPassword != nil ? "feedPassword=" + feedPassword! : "")
    }
}

class SpotDataRetreiver: NSObject, XMLParserDelegate {
    var loginInfo = SpotLoginInfo()
    private var lastMessageTime: Date?
    private var dataRetreiveOperationQueue = DataRetreiveOperationQueue()
    private var refreshTimer: Timer?
//    private var pagingRetreivedData = false
    
    override init() {
        super.init()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.50, repeats: true) { _ in self.executeDataRetreiveOperation() }
    }
    
    func refreshData(forceRefreshAll: Bool = false) {
        // If there is no recorded last message time, do a full refresh paging through all the data. Otherwise, refresh since the last message time (unless a forceRefreshAll was requested).
        let userDefaults = UserDefaults.standard
        var lastMessageTimeWithOffset: Date?
        if let lastMessageTime = userDefaults.object(forKey: "LastMessageTime") as? Date {
            lastMessageTimeWithOffset = Calendar.current.date(byAdding: .second, value: -1, to: lastMessageTime)
        }
        if lastMessageTimeWithOffset != nil, !dataRetreiveOperationQueue.contains(dataRetreiveOperation: .retreiveAll), !forceRefreshAll {
            let dataRetreiveOperationWithOffset = DataRetreiveOperation.retreiveFromTime(lastMessageTimeWithOffset!)
            if !dataRetreiveOperationQueue.contains(dataRetreiveOperation: dataRetreiveOperationWithOffset) {
                dataRetreiveOperationQueue.enqueue(dataRetreiveOperationWithOffset)
            }
            
        } else {
            if !dataRetreiveOperationQueue.contains(dataRetreiveOperation: .retreiveAll) {
                dataRetreiveOperationQueue.enqueue(.retreiveAll)
            }
        }
    }
    
    func executeDataRetreiveOperation() { //todo use enclosure in timer instead
        let a = dataRetreiveOperationQueue.dequeue()
        print("refresh timer fired at \(Date()) with \(a)")
        switch a! {
        case .retreiveAll:
            dataRetreiveOperationQueue.enqueue(.retreiveFromMessageIndex(51))
        case let .retreiveFromMessageIndex(messageIndex):
            dataRetreiveOperationQueue.enqueue(.retreiveFromMessageIndex(messageIndex + 50))
        case let .retreiveFromTime(messageTime):
            break
        }
    }
    
//    func retreiveData() { //toremove
//        let userDefaults = UserDefaults.standard
//        let feedLastRetreivedTime = userDefaults.object(forKey: "FeedLastRetreivedTime") as? Date
//        let currentTime = Date()
//        let feedLastRetrievedTimeWithOffset = Calendar.current.date(byAdding: .second, value: -1, to: feedLastRetreivedTime!)
//        if let feedUrlFull = loginInfo.getFeedURL(fromTime: feedLastRetrievedTimeWithOffset, toTime: currentTime) {
//            userDefaults.set(currentTime, forKey: "FeedLastRetreivedTime")
//            userDefaults.synchronize()
//            if let url = URL(string: feedUrlFull) {
//                if let xmlParser = XMLParser(contentsOf: url) {
//                    xmlParser.delegate = self
//                    xmlParser.parse()
//                }
//            }
//        }
//    }
    
    private var buffer: String = ""
    
    func parserDidStartDocument(_ parser: XMLParser) {
        print("start of XML")
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        print("End of XML")
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        buffer = ""
        print("Start of \(elementName)")
        
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        print("\(buffer)")
        print("End of \(elementName)")
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }
}

//
//  SpotDataRetreiver.swift
//  Tracker
//
//  Created by Warren Kadosh on 2016-12-31.
//  Copyright © 2016 Warren Kadosh. All rights reserved.
//

import Foundation
import CoreData

struct Queue<T> {
    private var array = Array<T>()
    
    public var isEmpty: Bool {
        return array.isEmpty
    }
    
    public mutating func enqueue(_ element: T) {
        array.append(element)
    }
    
    public mutating func dequeue() -> T? {
        guard !array.isEmpty, let element = array.first else { return nil }
        
        array.remove(at: 0)
        
        return element
    }
    
    public func peek() -> T? {
        return array.first
    }
}

struct SpotTraceLoginInfo {
    var feedID: String?
    var feedPassword: String?
    
    func getFeedURL(fromTime: Date?, toTime: Date?) -> String? {
        guard feedID != nil else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss-0000"
        //        let fromTimeParameter = fromTime != nil ? "startDate=" + dateFormatter.string(from: fromTime!) + "&" : ""
        let fromTimeParameter = "" //todo
        let toTimeParameter = toTime != nil ? "endDate=" + dateFormatter.string(from: toTime!) + "&" : ""
        print("https://api.findmespot.com/spot-main-web/consumer/rest-api/2.0/public/feed/\(feedID!)/message.xml?" + fromTimeParameter + toTimeParameter + (feedPassword != nil ? "feedPassword=" + feedPassword! : ""))
        return "https://api.findmespot.com/spot-main-web/consumer/rest-api/2.0/public/feed/\(feedID!)/message.xml?" + fromTimeParameter + toTimeParameter + (feedPassword != nil ? "feedPassword=" + feedPassword! : "")
    }
}

class SpotDataRetreiver: NSObject, XMLParserDelegate {
    var loginInfo = SpotTraceLoginInfo()
    
    func retreiveData() {
        let userDefaults = UserDefaults.standard
        let feedLastRetreivedTime = userDefaults.object(forKey: "FeedLastRetreivedTime") as? Date
        let currentTime = Date()
        let feedLastRetrievedTimeWithOffset = Calendar.current.date(byAdding: .second, value: -1, to: feedLastRetreivedTime!)
        if let feedUrlFull = loginInfo.getFeedURL(fromTime: feedLastRetrievedTimeWithOffset, toTime: currentTime) {
            userDefaults.set(currentTime, forKey: "FeedLastRetreivedTime")
            userDefaults.synchronize()
            if let url = URL(string: feedUrlFull) {
                if let xmlParser = XMLParser(contentsOf: url) {
                    xmlParser.delegate = self
                    xmlParser.parse()
                }
            }
        }
    }
    
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

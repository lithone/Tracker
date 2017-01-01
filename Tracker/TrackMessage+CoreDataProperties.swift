//
//  TrackMessage+CoreDataProperties.swift
//  Tracker
//
//  Created by Warren Kadosh on 2016-12-31.
//  Copyright © 2016 Warren Kadosh. All rights reserved.
//

import Foundation
import CoreData


extension TrackMessage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TrackMessage> {
        return NSFetchRequest<TrackMessage>(entityName: "TrackMessage");
    }

    @NSManaged public var batteryState: String?
    @NSManaged public var id: Int64
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var senderId: String?
    @NSManaged public var senderName: String?
    @NSManaged public var time: NSDate?
    @NSManaged public var type: String?
    @NSManaged public var trackMessageChain: TrackMessageChain?

}

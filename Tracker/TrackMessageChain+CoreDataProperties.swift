//
//  TrackMessageChain+CoreDataProperties.swift
//  Tracker
//
//  Created by Warren Kadosh on 2016-12-31.
//  Copyright © 2016 Warren Kadosh. All rights reserved.
//

import Foundation
import CoreData


extension TrackMessageChain {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TrackMessageChain> {
        return NSFetchRequest<TrackMessageChain>(entityName: "TrackMessageChain");
    }

    @NSManaged public var firstMessageId: Int64
    @NSManaged public var trackMessages: NSSet?

}

// MARK: Generated accessors for trackMessages
extension TrackMessageChain {

    @objc(addTrackMessagesObject:)
    @NSManaged public func addToTrackMessages(_ value: TrackMessage)

    @objc(removeTrackMessagesObject:)
    @NSManaged public func removeFromTrackMessages(_ value: TrackMessage)

    @objc(addTrackMessages:)
    @NSManaged public func addToTrackMessages(_ values: NSSet)

    @objc(removeTrackMessages:)
    @NSManaged public func removeFromTrackMessages(_ values: NSSet)

}

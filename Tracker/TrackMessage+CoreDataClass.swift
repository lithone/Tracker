//
//  TrackMessage+CoreDataClass.swift
//  Tracker
//
//  Created by Warren Kadosh on 2016-12-31.
//  Copyright © 2016 Warren Kadosh. All rights reserved.
//

import Foundation
import CoreData


public class TrackMessage: NSManagedObject {
    enum MessageType {
        case ok
        case track
        case extremeTrack
        case unlimitedTrack
        case newMovement
        case help
        case helpCancel
        case custom
        case poi
        case stop
    }
    enum BatteryState {
        case good
    }
}

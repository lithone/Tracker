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
    enum MessageType: String {
        case ok = "OK"
        case track = "TRACK"
        case extremeTrack = "EXTREME-TRACK"
        case unlimitedTrack = "UNLIMITED-TRACK"
        case newMovement = "NEWMOVEMENT"
        case help = "HELP"
        case helpCancel = "HELP-CANCEL"
        case custom = "CUSTOM"
        case poi = "POI"
        case stop = "STOP"
    }
    enum BatteryState: String {
        case good = "GOOD"
    }
}

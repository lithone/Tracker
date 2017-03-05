//
//  ViewController.swift
//  Tracker
//
//  Created by Warren Kadosh on 2016-12-31.
//  Copyright © 2016 Warren Kadosh. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController {
    var dataRetreiver: SpotDataRetreiver?
    private var managedObjectContext: NSManagedObjectContext? = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Set up data retreival.
        let feedId = UserDefaults.standard.string(forKey: "feedId")
        let feedPassword = UserDefaults.standard.string(forKey: "feedPassword")
        
        guard feedId != nil && feedPassword != nil && self.managedObjectContext != nil else {
            print("Unable to initialize data retreival. ")
            return
        }
        dataRetreiver = SpotDataRetreiver(feedId: feedId!, feedPassword: feedPassword!, context: self.managedObjectContext!)

        // Set up background refresh.
        UIApplication.shared.setMinimumBackgroundFetchInterval((dataRetreiver?.loginInfo.idleRefreshSeconds)!)
        
        // Start data retreival. 
        dataRetreiver?.orderMessageRefresh()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
}

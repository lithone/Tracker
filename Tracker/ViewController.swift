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
    private var dataRetreiver = SpotDataRetreiver()
    private var managedObjectContext: NSManagedObjectContext? = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    
        UserDefaults.standard.register(defaults: [String: Any]())
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        dataRetreiver.loginInfo.feedID = UserDefaults.standard.string(forKey: "feedId")
        dataRetreiver.loginInfo.feedPassword = UserDefaults.standard.string(forKey: "feedPassword")
        dataRetreiver.managedObjectContext = self.managedObjectContext
        
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "TrackMessage") //todo doing a full requery for now. 
        let r = NSBatchDeleteRequest(fetchRequest: fetch)
        _ = try? managedObjectContext?.execute(r)
        
        dataRetreiver.refreshData()
    }
}

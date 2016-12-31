//
//  ViewController.swift
//  Tracker
//
//  Created by Warren Kadosh on 2016-12-31.
//  Copyright © 2016 Warren Kadosh. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    private var dataRetreiver = SpotDataRetreiver()

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
        dataRetreiver.loginInfo.feedID = UserDefaults.standard.string(forKey: "feedID")
        dataRetreiver.loginInfo.feedPassword = UserDefaults.standard.string(forKey: "feedPassword")
        
        dataRetreiver.retreiveData()
    }
}


//
//  resultsViewController.swift
//  mainAppTest
//
//  Created by Stefan Alexander on 2014/09/11.
//  Copyright (c) 2014年 ステファンアレクサンダー. All rights reserved.
//

import UIKit

class resultsViewController: UIViewController {
    
    var playerwin:Bool! = false
    var leveledUp:Bool! = false
    
    @IBOutlet weak var playerWinLabel: UILabel!
    @IBOutlet weak var detailsLabel: UILabel!
    
    @IBAction func continuePressed(sender: AnyObject) {
        if (leveledUp == true) {
            performSegueWithIdentifier("results_assign", sender: self)
        }
        else {
            performSegueWithIdentifier("results_map", sender: self)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        var prefs = NSUserDefaults.standardUserDefaults()
        var plStats:[String:[String:AnyObject]] = prefs.objectForKey("playerStats") as [String:[String:AnyObject]]
        var currentuser = prefs.objectForKey("currentuser") as String
        var health:Int = plStats[currentuser]!["health"]! as Int
        var strength:Int = plStats[currentuser]!["strength"]! as Int
        var magic:Int = plStats[currentuser]!["magic"]! as Int
        var speed:Int = plStats[currentuser]!["speed"]! as Int
        var exp:Int = plStats[currentuser]!["exp"]! as Int
        var level:Int = plStats[currentuser]!["level"]! as Int
        
        detailsLabel.numberOfLines = 0
        detailsLabel.text = ""
        
        if (playerwin == true) {
            playerWinLabel.text = "You win!"
            postLog("I won.")
            if (leveledUp == true) {
                postLog("I leveled up (\(level-1) → \(level))")
                detailsLabel.text = "Level up! (\(level-1) → \(level))\n+10 assignment points!\n\n"
            }
            detailsLabel.text = detailsLabel.text! + "+1 enemies beaten.\n+1 EXP\n"
        }
        else {
            postLog("I lost.")
            playerWinLabel.text = "You lose."
            detailsLabel.text = detailsLabel.text! + "-1 EXP\n"
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> Int {
        return Int(UIInterfaceOrientationMask.Portrait.toRaw())
    }
}

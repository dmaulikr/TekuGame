//
//  MapViewController.swift
//  mainAppTest
//
//  Created by ステファンアレクサンダー on 2014/08/18.
//  Copyright (c) 2014年 ステファンアレクサンダー. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import CoreMotion
import Darwin

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate{
    
    var didButtonSegue = false;
    
    @IBAction func testButtonPressed(sender: AnyObject) {
        didButtonSegue = true;
        performSegueWithIdentifier("map_setup", sender: self)
    }
    
    
    @IBOutlet weak var encountLabel: UILabel!
    
    // MapKit, CoreLocation
    @IBOutlet weak var statusButton: UIButton!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var magicStepsLabel: UILabel!
    @IBOutlet weak var magicHourLabel: UILabel!
    var clManager = CLLocationManager()
    var playerID:String!                    // Player's ID passed from the previous ViewController.
    var lat:NSNumber!                       // Player's GPS coordinates (latitude).
    var long:NSNumber!                      // Player's GPS coordinates (longitude).
    var altitudeNum:Float! = 0
    var vAcc:Float! = 0
    var speedNum:Double! = 0
    var allPins:[GMSMarker] = []         // All of the pins set on the Map including preset pins and players.
    var presetPins:[GMSMarker] = []      // Array of only the preset pins.
    var near_beacon:NSMutableArray = []     // Array of players with the same nearby beacon.
    
    // Internet Connection.
    @IBOutlet weak var netConnectionLabel: UILabel!
    
    // iBeacon
    let proximityUUID = NSUUID(UUIDString:"B9407F30-F5F8-466E-AFF9-25556B57FE6D")   // UUID of iBeacon.
    var region  = CLBeaconRegion()                                                  // Region defined for iBeacons.
    var manager = CLLocationManager()                                               // Location manager for iBeacons.
    var beaconID:String! = ""                                                       // ID of the nearest beacon.
    @IBOutlet weak var beaconDistanceProgressBar: UIProgressView!
    @IBOutlet weak var beaconJoinBtn: UIButton!
    @IBOutlet weak var beaconIDLabel: UILabel!
    var beaconDictionary:[String:[String:String]]! = ["":["":""]]
    @IBOutlet weak var beaconView: UIView!
    
    // CoreMotion
    @IBOutlet var steplabel: UILabel!   // Label display number of counts of today's steps.
    var stepCount:Int! = 0                  // Number of steps.
    var prevSteps:Int! = 0                  // Number of steps since the start of the day until the application has launched.
    var activitystring:String! = ""
    var confidencenum:Float! = 0
    
    var healthGoal:Int = 0
    var speedFloat:Float = 0
    var enemiesDefeated:Int! = 0
    var magicHourInt:Int! = 0
    var currentHourInt:Int! = 0
    var prevMagicSteps:Int! = 0
    var magicSteps:Int! = 0
    var magicGoal:Int = 0
    var enemiesGoal:Int = 0
    var enemyStepCount:Int = 0
    
    var labelTimer:NSTimer!
    var statusTimer:NSTimer!
    var postGetTimer:NSTimer!
    var encounterTimer:NSTimer!
    
    var prefs = NSUserDefaults.standardUserDefaults()
    var plStats:[String:[String:AnyObject]] = [:]
    
    // Google Maps things.
    @IBOutlet var mainView:UIView!
    var mapView_:GMSMapView!
    var timer:NSTimer!
    var mapShown:Bool! = false
    @IBOutlet weak var currentLocationBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        var stepCounter = CMStepCounter()
        
        getHistoricalSteps({numberOfSteps, error in self.prevSteps = numberOfSteps})
        var stepsHandler:(Int, NSDate!, NSError!) -> Void = { numberOfSteps, timestamp, error in
            self.stepCount = numberOfSteps + self.prevSteps
            self.magicSteps = self.prevMagicSteps
            if (self.currentHourInt == self.magicHourInt) {
                self.magicSteps = self.prevMagicSteps + numberOfSteps
            }
        }
        var activityHandler:(CMMotionActivity!) -> Void = { activity in
            if (activityToString(activity) != "") {
                self.activitystring = activityToString(activity)
                self.confidencenum = Float(activity.confidence.toRaw())
            }
        }
        updateSteps(stepsHandler, activityHandler)
        
        setButton()
        beaconSetup()
        
        if (isConnectedToInternet()) {
            initialMapSetup()
            getPlayerLocation()
            postPlayerStats()
            mapShown = true
            beaconView.hidden = false
            clManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            clManager.startUpdatingLocation()
            clManager.delegate = self
        }
        else {
            netConnectionLabel.text = "No Internet"
            beaconView.hidden = true
            currentLocationBtn.hidden = true
            currentLocationBtn.enabled = false
        }
        
        plStats = prefs.objectForKey("playerStats") as [String:[String:AnyObject]]
        speedFloat = plStats[playerID]!["speedProgress"]! as Float
        prevMagicSteps = plStats[playerID]!["magicSteps"]! as Int
        magicSteps = prevMagicSteps
        
        prefs.setObject(true, forKey: "loggedIn")

        
        var versionstr:NSString = UIDevice.currentDevice().systemVersion
        var versiondouble = versionstr.doubleValue
        if (versiondouble >= 8.0) {
            clManager.requestWhenInUseAuthorization()
        }
        labelTimer = setInterval("updateStepLabel", seconds: 1)
        statusTimer = setInterval("checkStatus", seconds: 2)
        postGetTimer = setInterval("postAndGet", seconds: 30)
        encounterTimer = setInterval("checkEncounter", seconds: 1)
    }
    
    func setButton() {
        var currentuser = prefs.objectForKey("currentuser") as String
        playerID = currentuser
        var idonly = playerID.componentsSeparatedByString("(")[0]
        statusButton.setTitle("@\(idonly)", forState: UIControlState.Normal)
    }
    
    // Calls the given function every n seconds.
    func setInterval(functionname:String, seconds:NSNumber) -> NSTimer {
        return NSTimer.scheduledTimerWithTimeInterval(seconds, target: self, selector: Selector(functionname), userInfo: nil, repeats: true)
    }
    
    // Initial setup for map.
    func initialMapSetup() {
        var initlat:CLLocationDegrees = 35.6896
        var initlong:CLLocationDegrees = 139.6917
        var initzoom:Float = 0
        
        if (prefs.objectForKey("camera") != nil) {
            var cam = prefs.objectForKey("camera") as [String:Double]
            initlat = cam["lat"]!
            initlong = cam["long"]!
            initzoom = Float(cam["zoom"]!)
            positionMap(&mainView, &mapView_, initlat, initlong, initzoom)
        }
        else {
            positionMap(&mainView, &mapView_, initlat, initlong, initzoom)
            // Wait until current location is found to zoom to that place.
            timer = setInterval("gotoCurrentLocation", seconds: 1)
        }
        
        // getJSON from beacon database,
        // add to preset pins and all pins
        // also add to dictionary
        getBeacons()
    }
    
    func getBeacons() {
        var url = "http://tekugame.mxd.media.ritsumei.ac.jp/json/beacons.json"
        var jsObj = getJSON(url)
        
        if (jsObj != nil) {
            for data in jsObj! {
                var bid = data["ID"] as NSString
                var long = data["longitude"] as NSString
                var lat = data["latitude"] as NSString
                var pneed = data["playersNeeded"] as NSString
                
                beaconDictionary[bid] = ["longitude":long, "latitude":lat, "playersNeeded":pneed]
                
                var marker = setMarker(&mapView_, lat.doubleValue, long.doubleValue, "Beacon: \(bid)", "Players Needed: \(pneed)", UIColor.blueColor())
                presetPins.append(marker)
                allPins.append(marker)
            }
        }
    }
    
    func gotoCurrentLocation() {
        if (mapView_.myLocation != nil) {
            moveCameraToTarget(mapView_.myLocation.coordinate, zoom: 15)
            if (timer != nil) {
                timer.invalidate()
                timer = nil
            }
        }
    }
    
    func moveCameraToTarget(target:CLLocationCoordinate2D, zoom:Float) {
        var update:GMSCameraUpdate = GMSCameraUpdate.setTarget(target, zoom: zoom)
        mapView_.animateWithCameraUpdate(update)
    }
    
    // Setup for beacon.
    func beaconSetup() {
        println("beaconSetup")
        beaconView.hidden = true
        region = CLBeaconRegion(proximityUUID:proximityUUID,identifier:"EstimoteRegion")
        manager.delegate = self
        switch CLLocationManager.authorizationStatus() {
        case .Authorized, .AuthorizedWhenInUse:
            println("startRangingBeaconsInRegion")
            self.manager.startRangingBeaconsInRegion(self.region)
        case .NotDetermined:
            println("NotDetermined")
            let position = 1
            let index = advance(UIDevice.currentDevice().systemVersion.startIndex, position)
            let numb = UIDevice.currentDevice().systemVersion[index]
            
            if(String(numb).toInt() >= 8) {
                //iOS8以降は許可をリクエストする関数をCallする
                self.manager.requestAlwaysAuthorization()
            }
            else {
                self.manager.startRangingBeaconsInRegion(self.region)
            }
        case .Restricted, .Denied:
            currentLocationBtn.hidden = true
            currentLocationBtn.enabled = false
        }
    }
    
    // Move to the user's current location.
    @IBAction func updateLocation(sender: AnyObject) {
        gotoCurrentLocation()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Simply posts and gets.
    func postAndGet() {
        if (isConnectedToInternet()) {
            postPlayerLocation(playerID, beaconID, mapView_)
            postPlayerStats()
            getPlayerLocation()
        }
    }
    
    // Gets JSON data from the server and updates corresponding fields such as pins on the map and number of nearby players.
    func getPlayerLocation() {
        let url = "http://tekugame.mxd.media.ritsumei.ac.jp/json/playerandlocation.json"
        var jsObj = getJSON(url)
        
        if (jsObj != nil) {
            near_beacon = []
            
            resetPins()
            
            for data in jsObj! {
                var pid = data["phoneid"] as NSString
                var bid = data["beaconid"] as NSString
                var lati = data["latitude"] as NSString
                var lon = data["longitude"] as NSString
                var dat = data["date"] as NSString
                
                var displaydate = returnDateDifferenceString(dat)
                
                if (pid != playerID) {
                    var plCoordinate :CLLocationCoordinate2D = CLLocationCoordinate2DMake(lati.doubleValue, lon.doubleValue)
                    var pl = setMarker(&mapView_, lati.doubleValue, lon.doubleValue, pid, displaydate, UIColor.redColor())
                    allPins.append(pl)
                }
//                if (bid == beaconID) {
//                    near_beacon.addObject(data)
////                    beaconPlayerCountLabel.text = "\(near_beacon.count)"
//                }
            }
        }
    }
    
    // Resets the pins on the map.
    func resetPins() {
        
        for pin in allPins {
            // If not a preset pin, then it is a player pin so delete it.
            if (find(presetPins, pin) == nil) {
                pin.map = nil
            }
        }
        
        var temparr:[GMSMarker] = []
        
        for pin in allPins {
            if (pin.map != nil) {
                temparr.append(pin)
            }
        }
        allPins = temparr
    }
    
    func locationManager(manager: CLLocationManager!, didStartMonitoringForRegion region: CLRegion!) {
        println("didStartMonitoringForRegion")
        manager.requestStateForRegion(region)
    }
    
    func locationManager(manager: CLLocationManager!, didDetermineState state: CLRegionState, forRegion inRegion: CLRegion!) {
        println("didDetermineState")
        if (state == .Inside) {
            manager.startRangingBeaconsInRegion(region)
        }
    }
    
    func locationManager(manager: CLLocationManager!, monitoringDidFailForRegion region: CLRegion!, withError error: NSError!) {
        println("monitoringDidFailForRegion \(error)")
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        println("didFailWithError")
    }
    
    func locationManager(manager: CLLocationManager!, didEnterRegion region: CLRegion!) {
        println("didEnterRegion")
        manager.startRangingBeaconsInRegion(region as CLBeaconRegion)
    }
    
    func locationManager(manager: CLLocationManager!, didExitRegion region: CLRegion!) {
        println("didExitRegion")
        manager.stopRangingBeaconsInRegion(region as CLBeaconRegion)
    }
    
    func locationManager(manager: CLLocationManager!, didRangeBeacons beacons: NSArray!, inRegion region: CLBeaconRegion!) {
        
        if(beacons.count == 0) { return }
        
        var beacon = beacons[0] as CLBeacon
        
        /*
        beaconから取得できるデータ
        proximityUUID   :   regionの識別子
        major           :   識別子１
        minor           :   識別子２
        proximity       :   相対距離
        accuracy        :   精度
        rssi            :   電波強度
        */
        beaconID = "\(beacon.major)\(beacon.minor)"
        beaconIDLabel.text = "Beacon: \(beaconID)"
        
        println("beacon.proximity \(beacon.proximity) isequaltoUnknown??: \(beacon.proximity == CLProximity.Unknown)")
        
        
        if (Float(beacon.accuracy) <= 5.0 && beacon.proximity != CLProximity.Unknown) {
            beaconJoinBtn.enabled = true
        }
        else {
            beaconJoinBtn.enabled = false
        }
        
        if (beacon.proximity == CLProximity.Unknown) {
            beaconDistanceProgressBar.progress = 0
            beaconView.hidden = true
        }
        else if (mapShown == true) {
            beaconDistanceProgressBar.progress = (20.0 - Float(beacon.accuracy)) / 20.0
            beaconView.hidden = false
        }
    }
    
    func checkHealthGoal() {
        if (healthGoal == 0) {
            healthGoal = plStats[playerID]!["healthGoal"]! as Int
        }
        
        if (stepCount >= healthGoal) {
            healthGoal += 5000
            plStats[playerID]!["healthGoal"]! = healthGoal
            prefs.setObject(plStats, forKey: "playerStats")
            postLog("Walked \(stepCount) steps today, health incremented by 1.")
            updateLocalPlayerStats(1, 0, 0, 0, &plStats)
            UIAlertView(title: "Congratulations!", message: "Health incremented by 1.", delegate: nil, cancelButtonTitle: "OK").show()
        }
    }
    
    func checkRunningGoal() {
        if (activitystring.rangeOfString("Running") != nil && (confidencenum == Float(CMMotionActivityConfidence.High.toRaw()) || confidencenum == Float(CMMotionActivityConfidence.Medium.toRaw()))) {
            speedFloat += 0.01
        }
        
        if (speedFloat >= 1) {
            speedFloat = 0
            plStats[playerID]!["speedProgress"]! = speedFloat
            prefs.setObject(plStats, forKey: "playerStats")
            postLog("Speed incremented by 1 from running.")
            updateLocalPlayerStats(0, 0, 0, 1, &plStats)
            UIAlertView(title: "Congratulations!", message: "Speed incremented by 1.", delegate: nil, cancelButtonTitle: "OK").show()
        }
    }
    
    func checkMagicHour() {
        magicHourInt = plStats[playerID]!["magicHour"]! as Int
        var magicDate = plStats[playerID]!["date"]! as String
        
        if (magicDate != returnDateString()) {
            magicSteps = 0
            magicHourInt = Int(arc4random_uniform(16)) + 8
            updateEncounterStep(&enemyStepCount, stepCount)
            plStats[playerID]!["healthGoal"]! = 5000
            plStats[playerID]!["magicGoal"]! = 1000
            plStats[playerID]!["magicHour"]! = magicHourInt
            plStats[playerID]!["magicSteps"]! = 0
            plStats[playerID]!["date"]! = returnDateString()
            plStats[playerID]!["enemyStepCount"]! = enemyStepCount
            prefs.setObject(plStats, forKey: "playerStats")
        }

        magicHourLabel.text = "Magic Hour: \(magicHourInt):00"
        
        if (magicGoal == 0) {
            magicGoal = plStats[playerID]!["magicGoal"]! as Int
        }
        
        if (magicSteps >= magicGoal) {
            magicGoal += 1000
            plStats[playerID]!["magicGoal"]! = magicGoal
            prefs.setObject(plStats, forKey: "playerStats")
            postLog("Walked \(magicSteps) steps during magic hour (\(magicHourInt):00). Magic incremented by 1.")
            updateLocalPlayerStats(0, 0, 1, 0, &plStats)
            UIAlertView(title: "Congratulations!", message: "Magic incremented by 1.", delegate: nil, cancelButtonTitle: "OK").show()
        }
    }
    
    func checkEnemiesGoal() {
        
        if (enemiesDefeated == 0) {
            enemiesDefeated = plStats[playerID]!["enemiesDefeated"]! as Int
        }
        
        if (enemiesGoal == 0) {
            enemiesGoal = plStats[playerID]!["strengthGoal"]! as Int
        }
        
        if (enemiesDefeated >= enemiesGoal) {
            enemiesGoal += 3
            plStats[playerID]!["strengthGoal"]! = enemiesGoal
            prefs.setObject(plStats, forKey: "playerStats")
            postLog("Defeated \(enemiesDefeated) enemies. Strength incremented by 1.")
            updateLocalPlayerStats(0, 1, 0, 0, &plStats)
            UIAlertView(title: "Congratulations!", message: "Strength incremented by 1.", delegate: nil, cancelButtonTitle: "OK").show()
        }
    }
    
    // Simply updates the label for step count.
    func updateStepLabel() {
        steplabel.text = "Steps：\(stepCount) steps"

        if (confidencenum == Float(CMMotionActivityConfidence.High.toRaw()) || confidencenum == Float(CMMotionActivityConfidence.Medium.toRaw())) {
            activityLabel.text = activitystring
        }
        else {
            activityLabel.text = ""
        }
        magicStepsLabel.text = "Magic Steps: \(magicSteps) steps"
        plStats[playerID]!["speedProgress"]! = speedFloat
        plStats[playerID]!["magicSteps"]! = magicSteps
        prefs.setObject(plStats, forKey: "playerStats")
    }
    
    func checkStatus() {
        checkHealthGoal()
        checkRunningGoal()
        checkMagicHour()
        checkEnemiesGoal()
    }
    
    func checkEncounter() {
        
        if (enemyStepCount == 0) {
            enemyStepCount = plStats[playerID]!["enemyStepCount"]! as Int
        }
        var state = UIApplication.sharedApplication().applicationState
        if (enemyStepCount < stepCount && state == UIApplicationState.Active) {
            updateEncounterStep(&enemyStepCount, stepCount)
            plStats[playerID]!["enemyStepCount"]! = enemyStepCount
            prefs.setObject(plStats, forKey: "playerStats")
            encount()
        }
    }
    
    func encount() {
        var state = UIApplication.sharedApplication().applicationState
        if (state == UIApplicationState.Active) {
            postLog("Encountered enemy at \(stepCount).")
            performSegueWithIdentifier("map_game", sender: self)
            updateEncounterStep(&enemyStepCount, stepCount)
        }
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> Int {
        return Int(UIInterfaceOrientationMask.Portrait.toRaw())
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if (segue.identifier == "map_status") {
            var nextVC = segue.destinationViewController as statusViewController
            nextVC.stepCount = stepCount
        }
        else if (segue.identifier == "map_setup") {
            var nextVC = segue.destinationViewController as multiPlayerSetupViewController

            if(didButtonSegue == true)
            {
                nextVC.battleID = "0";
                nextVC.pneed = 1;
            }
            else
            {
                nextVC.battleID = beaconID
                var pneed = beaconDictionary[beaconID]!["playersNeeded"]! as NSString
                nextVC.pneed = pneed.integerValue
            }
        }
        
        if (mapShown == true) {
            var cam:[String:Double] = ["lat":mapView_.camera.target.latitude, "long":mapView_.camera.target.longitude, "zoom":Double(mapView_.camera.zoom)]
            prefs.setObject(cam, forKey: "camera")
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        if (labelTimer != nil) {
            labelTimer.invalidate()
            labelTimer = nil
        }
        if (statusTimer != nil) {
            statusTimer.invalidate()
            statusTimer = nil
        }
        if (postGetTimer != nil) {
            postGetTimer.invalidate()
            postGetTimer = nil
        }
        if (encounterTimer != nil) {
            encounterTimer.invalidate()
            encounterTimer = nil
        }
    }
}

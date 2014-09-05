//
//  listViewController.swift
//  multiplayerCombatTest
//
//  Created by Stefan Alexander on 2014/09/03.
//  Copyright (c) 2014年 Stefan Alexander. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class listViewController: UIViewController, MCNearbyServiceBrowserDelegate, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {
    
    // from segue
    var playerID:String!
    
    var myPeerID:MCPeerID!
    var serviceType:NSString!
    var nearbyServiceAdvertiser:MCNearbyServiceAdvertiser!
    var nearbyServiceBrowser:MCNearbyServiceBrowser!
    var session:MCSession!
    
    var otherPeerID:MCPeerID!
    var otherPeers:[MCPeerID] = []
    var otherPeersDict:[MCPeerID : [String : String]] = [:]
    
    var timer:NSTimer!
    
    var battleStarted = false
    var hostID:MCPeerID!
    
    var turn:String! = ""
    var choseAttack:Bool! = false
    
    @IBOutlet weak var playerTextView: UITextView!
    @IBOutlet weak var readyTextView: UITextView!
    @IBOutlet weak var battleTextView: UITextView!
    @IBOutlet weak var readySwitch: UISwitch!
    @IBOutlet weak var readyLabel: UILabel!
    @IBOutlet weak var attackTextField: UITextField!
    @IBOutlet weak var attackButton: UIButton!
    @IBOutlet weak var connectedPeersLabel: UILabel!
    
    @IBAction func readyTouched(sender: AnyObject) {
        startAdvertising()
        
        var readyBoolStr:String!
        if (readySwitch.on) {
            readyBoolStr = "true"
        }
        else {
            readyBoolStr = "false"
        }
        var mydict:[String:String] = ["display_name":playerID, "ready": readyBoolStr]
        
        var error:NSError?
        var data = NSKeyedArchiver.archivedDataWithRootObject(mydict)
        session.sendData(data, toPeers: session.connectedPeers, withMode: MCSessionSendDataMode.Reliable, error: &error)
        println("Error: \(error?.localizedDescription)")
    }
    
    @IBAction func attackTouched(sender: AnyObject) {
        var attack:String! = attackTextField.text
        attackTextField.text = ""
        choseAttack = true
        attackTextField.enabled = false
        attackButton.enabled = false
        turn = ""
        battleTextView.text = battleTextView.text + "You did a \(attack) to the enemy.\n"
        sendData(["attack":attack])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        var uuid:NSUUID = NSUUID.UUID()
        myPeerID = MCPeerID(displayName: uuid.UUIDString)
        var namePeerID:NSString = myPeerID.displayName
        
        serviceType = "p2pcombattest"
        
        nearbyServiceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        nearbyServiceBrowser.delegate = self
        
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.None)
        session.delegate = self
        
        startAdvertising()
        nearbyServiceBrowser.startBrowsingForPeers()
        
        setInterval("updatePlayerList", seconds: 1)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
    }
    
    func setInterval(functionname:String, seconds:NSNumber) -> NSTimer {
        return NSTimer.scheduledTimerWithTimeInterval(seconds, target: self, selector: Selector(functionname), userInfo: nil, repeats: true)
    }
    
    func updatePlayerList() {
        if (!battleStarted) {
            var count = 0
            playerTextView.text = "\(playerID)\n"
            if (readySwitch.on) {
                readyTextView.text = "○\n"
                count++
            }
            else {
                readyTextView.text = "×\n"
            }
            
            for pl in otherPeers {
                if (otherPeersDict[pl] != nil) {
                    playerTextView.text = playerTextView.text + otherPeersDict[pl]!["display_name"]! + "\n"
                    if (otherPeersDict[pl]!["ready"]! == "true") {
                        readyTextView.text = readyTextView.text + "○\n"
                        count++
                    }
                    else {
                        readyTextView.text = readyTextView.text + "×\n"
                    }
                }
            }
            if (count >= 2) {
                initBattle()
            }
        }
    }
    
    func initBattle() {
        
        sendData(["battle":"true"])
        
        battleStarted = true
        playerTextView.hidden = true
        readyTextView.hidden = true
        readySwitch.hidden = true
        readyLabel.hidden = true
        battleTextView.hidden = false
        battleTextView.text = "You have encountered a monster!\n"
        attackTextField.hidden = false
        attackButton.hidden = false
        
        setHost()
        
        setInterval("battle", seconds: 1)
    }
    
    func sendData(dict:[String:String]) {
        var mydict:[String:String] = dict
        var error:NSError?
        var data = NSKeyedArchiver.archivedDataWithRootObject(mydict)
        session.sendData(data, toPeers: session.connectedPeers, withMode: MCSessionSendDataMode.Reliable, error: &error)
    }
    
    func battle() {
        connectedPeersLabel.text = "\(session.connectedPeers.count)"
        battleTextView.scrollRangeToVisible(NSMakeRange(countElements(battleTextView.text), 0))
        if (hostID == myPeerID) {
            if (turn == "") {
                var peercount:Int! = session.connectedPeers.count
                var randomint:Int! = Int(arc4random_uniform(UInt32(peercount+2)))
                
                // Host
                if (randomint == peercount) {
                    turn = "host"
                    battleTextView.text = battleTextView.text + "It is your turn.\n"
                    attackTextField.enabled = true
                    attackButton.enabled = true
                }
                // Enemy
                else if (randomint == peercount + 1) {
                    turn = "enemy"
                    battleTextView.text = battleTextView.text + "It is the enemy's turn.\n"
                    attackTextField.enabled = false
                    attackButton.enabled = false
                    
                    enemyAttack()
                }
                // Other players
                else {
                    turn = session.connectedPeers[randomint].displayName
                    var pname:String! = otherPeersDict[session.connectedPeers[randomint] as MCPeerID]!["display_name"]!
                    battleTextView.text = battleTextView.text + "It is \(pname)'s turn.\n"
                    attackTextField.enabled = false
                    attackButton.enabled = false
                }
                NSThread.sleepForTimeInterval(2)
                sendData(["turn":turn])
            }
        }
        else {
            if (turn == myPeerID.displayName && !choseAttack) {
                attackTextField.enabled = true
                attackButton.enabled = true
            }
            else {
                
            }
        }
    }
    
    func enemyAttack() {
        var attacks:[String] = ["Punch", "Kick", "Fire", "Thunder", "Blizzard"]
        var randomint:Int! = Int(arc4random_uniform(UInt32(attacks.count)))
        battleTextView.text = battleTextView.text + "Enemy used \(attacks[randomint])\n"
        sendData(["enemy":attacks[randomint]])
        turn = ""
    }
    
    func setHost() {
        var hostIDText:String! = "\(myPeerID.displayName)"
        hostID = myPeerID
        for id in otherPeers {
            var IDText:String! = "\(id.displayName)"
            if (IDText < hostIDText) {
                hostIDText = IDText
                hostID = id
            }
        }
        
        if (hostIDText == "\(myPeerID.displayName)") {
            battleTextView.text = battleTextView.text + "I am the host.\n"
        }
        else {
            var hostname:String! = otherPeersDict[hostID]!["display_name"]!
            battleTextView.text = battleTextView.text + "\(hostname) is the host.\n"
        }
    }
    
    // Called when a browser failed to start browsing for peers. (required)
    func browser(browser: MCNearbyServiceBrowser!, didNotStartBrowsingForPeers error: NSError!) {
        if ((error) != nil) {
            println("error.localizedDescription \(error.localizedDescription)")
        }
    }
    
    // Called when a new peer appears. (required)
    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        nearbyServiceBrowser.invitePeer(peerID, toSession: session, withContext: "Welcome".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true), timeout: 10)
        var peer_name:AnyObject! = info["display_name"]
        var pname:String = peer_name as String
        var ready:AnyObject! = info["ready"]
        var rstr:String = ready as String
        dispatch_async(dispatch_get_main_queue(), {
            if (find(self.otherPeers, peerID) == nil) {
                self.otherPeers.append(peerID)
            }
            self.otherPeersDict[peerID] = ["display_name" : pname, "ready" : rstr]
        })
    }
    
    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {
        var index = 0
        for id in otherPeers {
            if (id == peerID) {
                break
            }
            index++
        }
        
        var pname = otherPeersDict[peerID]!["display_name"]!
        if (battleStarted) {
            battleTextView.text = battleTextView.text + "Lost connection with \(pname)\n"
            if (peerID == hostID) {
                otherPeers.removeAtIndex(index)
                setHost()
            }
            else {
                otherPeers.removeAtIndex(index)
            }
        }
        else {
            otherPeers.removeAtIndex(index)
        }
    }
    
    // Called when advertisement fails. (required)
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didNotStartAdvertisingPeer error: NSError!) {
        if (error != nil) {
            println(error.localizedDescription)
        }
    }
    
    // Called when a remote peer invites the app to join a session. (required)
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {
        invitationHandler(true, session)
    }
    
    // Called when a remote peer sends an NSData object to the local peer. (required)
    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {
        dispatch_async(dispatch_get_main_queue(), {
            var dict:[String:String]! = NSKeyedUnarchiver.unarchiveObjectWithData(data) as [String:String]!
            println("Connected: \(session.connectedPeers.count)")
            if (dict["display_name"] != nil) {
                var pname:String! = dict["display_name"] as String!
                var ready:String! = dict["ready"] as String!
                
                self.otherPeersDict[peerID] = ["display_name" : pname, "ready" : ready]
            }
            else if (dict["battle"] != nil) {
                if (!self.battleStarted) {
                    self.initBattle()
                }
            }
            else if (dict["turn"] != nil) {
                self.turn = dict["turn"] as String!
                if (self.turn == self.myPeerID.displayName) {
                    self.battleTextView.text = self.battleTextView.text + "It is your turn.\n"
                    self.choseAttack = false
                }
                else if (self.turn == "enemy") {
                    self.battleTextView.text = self.battleTextView.text + "It is the enemy's turn.\n"
                }
                else if (self.turn != "") {
                    var pname = self.otherPeersDict[self.hostID]!["display_name"]!
                    self.battleTextView.text = self.battleTextView.text + "It is \(pname)'s turn.\n"
                }
            }
            else if (dict["attack"] != nil) {
                self.turn = ""
                var attack = dict["attack"] as String!
                var pname = self.otherPeersDict[peerID]!["display_name"]!
                self.battleTextView.text = self.battleTextView.text + "\(pname) used \(attack) to the enemy.\n"
            }
            else if (dict["enemy"] != nil) {
                self.turn = ""
                var enemyattack = dict["enemy"] as String!
                self.battleTextView.text = self.battleTextView.text + "It is the enemy's turn.\nEnemy used \(enemyattack).\n"
            }
        })
    }
    
    // Called when a remote peer begins sending a file-like resource to the local peer. (required)
    func session(session: MCSession!, didStartReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!) {
        println("didStartReceivingResourceWithName")
    }
    
    // Called when a remote peer sends a file-like resource to the local peer. (required)
    func session(session: MCSession!, didFinishReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, atURL localURL: NSURL!, withError error: NSError!) {
        println("didFinishReceivingResourceWithName")
    }
    
    // Called when a remote peer opens a byte stream connection to the local peer. (required)
    func session(session: MCSession!, didReceiveStream stream: NSInputStream!, withName streamName: String!, fromPeer peerID: MCPeerID!) {
        println("didReceiveStream")
    }
    
    // Called when the state of a remote peer changes. (required)
    func session(session: MCSession!, peer peerID: MCPeerID!, didChangeState state: MCSessionState) {
        println("peerID \(peerID)")
        println("state \(state) ")
        
    }
    
    // Called to authenticate a remote peer when the connection is first established. (required)
    func session(session: MCSession!, didReceiveCertificate certificate: [AnyObject]!, fromPeer peerID: MCPeerID!, certificateHandler: ((Bool) -> Void)!) {
        certificateHandler(true)
    }
    
    func startAdvertising() {
        var ready = "false"
        if (readySwitch.on) {
            ready = "true"
        }
        var discoveryInfo:NSDictionary = NSDictionary(objects: [playerID, ready], forKeys: ["display_name", "ready"])
        nearbyServiceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        nearbyServiceAdvertiser.delegate = self
        nearbyServiceAdvertiser.startAdvertisingPeer()
    }
    
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        self.view.endEditing(true)
    }
    
    override func viewDidDisappear(animated: Bool) {
        playerTextView.text = ""
        if (timer != nil) {
            timer.invalidate()
        }
        timer = nil
    }
    
}



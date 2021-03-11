//
//  Config.swift
//  SwimPace
//
//  Created by Tom on 2/19/21.
//

import Cocoa

class Config: NSObject {
    
    // Race Defaults
    @objc dynamic var raceDistance:Int = 500
    @objc dynamic var raceQualifyingTime:Double = 314.1528
    
    // Pool Defaults
    @objc dynamic var poolLength:Int = 50
    @objc dynamic var showPoolOutline:Bool = false
    
    // Pace Bar
    @objc dynamic var showPaceBar:Bool  = false
    @objc dynamic var paceBarColor:NSColor = NSColor.red
    @objc dynamic var paceBarWidth:Int = 20
    @objc dynamic var paceBarString:String = "qualifying pace"
    @objc dynamic var paceBarStringColor:NSColor = NSColor.white
    
    // Camera
    @objc dynamic var windowTitleBarVisible = true
    @objc dynamic var cameraInfo:CameraInfo = CameraInfo(id:"Foo", displayName:"Bar")


}

//
//  ViewController.swift
//  SwimPace
//
//  Created by Tom on 2/19/21.
//

import Cocoa

protocol ConfigControllerDelegate {
    func didClose(_ configController:ConfigController)
    
}

class ConfigController: NSViewController {

    var delegate:ConfigControllerDelegate?
    
    @IBOutlet var poolLengthArrayController: NSArrayController!
    @IBOutlet var raceLengthArrayController: NSArrayController!
    @IBOutlet var poolUnitsArrayController: NSArrayController!
    @IBOutlet var barWidthsArrayController: NSArrayController!
        
    // Race
    @IBOutlet weak var raceDistancePopup: NSPopUpButton!
    @IBOutlet weak var racePaceTextField: NSTextField!
    
    // Pool
    @IBOutlet weak var poolLengthPopup: NSPopUpButton!
    @IBOutlet weak var poolLengthUnits: NSPopUpButton!
    @IBOutlet weak var showPoolOutlineSwitch: NSSwitch!
    
    // Pace Bar
    @IBOutlet weak var paceBarVisibleSwitch: NSSwitch!
    @IBOutlet weak var paceBarColorWell: NSColorWell!
    @IBOutlet weak var paceBarWidthPopUpButton: NSPopUpButton!
    @IBOutlet weak var paceBarCaptionTextField: NSTextField!
    @IBOutlet weak var paceBarCaptionColorWell: NSColorWell!
    // Font Selector
    

    private var poolLengths = [25, 50, 100]
    private var raceLengths = [50, 100, 200, 400, 500]
    private var barWidths = [Int]()
    
    private var cameraFeed:CameraFeed?

    
    private var poolWindowController:NSWindowController?
    private var poolViewController:PoolViewController?
    
    @objc dynamic var config:Config = Config()
    
    private var timeNumberFormatter = HHMMSSFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.raceLengthArrayController.content = raceLengths
        self.poolLengthArrayController.content = poolLengths
        self.poolUnitsArrayController.content = ["meters", "yards"]
        
        (1...5).forEach { barWidths.append($0*5)}
        self.barWidthsArrayController.content = barWidths
        
        // Race Defaults
        raceDistancePopup.select(raceDistancePopup.item(withTitle: "\(self.config.raceDistance)"))
        racePaceTextField.stringValue = timeNumberFormatter.string(from: NSNumber(value: self.config.raceQualifyingTime)) ?? "00:00"
        
        // Pool Defaults
        poolLengthPopup.select(poolLengthPopup.item(withTitle: "\(self.config.poolLength)"))
        poolLengthUnits.selectItem(at: 0)
        showPoolOutlineSwitch.state = self.config.showPoolOutline == true ? .on : .off
        
        // Pace Bar Defaults
        paceBarVisibleSwitch.state = self.config.showPaceBar == true ? .on : .off
        paceBarColorWell.color = self.config.paceBarColor
        paceBarWidthPopUpButton.select(paceBarWidthPopUpButton.item(withTitle: "\(self.config.paceBarWidth)"))
        paceBarCaptionTextField.stringValue = self.config.paceBarString
        paceBarCaptionColorWell.color = self.config.paceBarStringColor


        timeNumberFormatter.numberStyle = .none
        timeNumberFormatter.groupingSize = 2
        timeNumberFormatter.groupingSeparator = ":"
        timeNumberFormatter.usesGroupingSeparator = true
        timeNumberFormatter.maximumFractionDigits = 2
        timeNumberFormatter.maximumFractionDigits = 6
        timeNumberFormatter.minimumIntegerDigits = 6
        timeNumberFormatter.maximumIntegerDigits = 6
        
        self.racePaceTextField.delegate = self

    }
    
    // MARK: - IBActions
    
    @IBAction func closeButtonAction(_ sender: Any) {
        self.delegate?.didClose(self)
    }
    
    @IBAction func raceDistanceChanged(_ sender: Any) {
        if let popup = sender as? NSPopUpButton {
            self.config.raceDistance =  raceLengths[popup.indexOfSelectedItem]
        }
    }
    
    @IBAction func titleBarSwitchAction(_ sender: Any) {
        if let swtch = sender as? NSSwitch {
            self.config.windowTitleBarVisible = swtch.state == .on ? true : false
        }
    }
    
    @IBAction func showPoolOutlineSwitchAction(_ sender: Any) {
        if let swtch = sender as? NSSwitch {
            self.config.showPoolOutline = swtch.state == .on ? true : false
        }
    }
    
    @IBAction func paceBarColorWellChangeAction(_ sender: Any) {
        if let colorWell = sender as? NSColorWell {
            self.config.paceBarColor = colorWell.color
        }
    }
    
    @IBAction func paceBarCaptionColorWellChangeAction(_ sender: Any) {
        if let colorWell = sender as? NSColorWell {
            self.config.paceBarStringColor = colorWell.color
        }
    }
    
    @IBAction func paceBarWidthPopUpChange(_ sender: Any) {
        if let popup = sender as? NSPopUpButton {
            self.config.paceBarWidth = barWidths[popup.indexOfSelectedItem]
        }
    }
    
    @IBAction func showPaceBarSwitchChange(_ sender: Any) {
        if let swtch = sender as? NSSwitch {
            self.config.showPaceBar = swtch.state == .on ? true : false
        }
    }
}

extension ConfigController: NSTextFieldDelegate {
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if let textField = control as? NSTextField {
            if let number = timeNumberFormatter.number(from: textField.stringValue) {
                self.config.raceQualifyingTime = number.doubleValue
                textField.stringValue = timeNumberFormatter.string(from: number) ?? "error1"
            } else {
                self.config.raceQualifyingTime = 0
                // TODO: make a bonk noise or something here
                print("bonk noise here")
                textField.stringValue = timeNumberFormatter.string(from: 0) ?? "error2"
            }
        }
        return true
    }
}

class HHMMSSFormatter:NumberFormatter {
    
    override func string(from number: NSNumber) -> String? {
        let time:Double = number.doubleValue
        let hours:Int = Int(time / 3600)
        let minutes:Int = (Int(time) - (hours * 3600)) / 60
        let seconds:Double = time - Double(hours * 3600) - Double(minutes * 60)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%06.3f", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%06.3f", minutes, seconds)
        }
    }
    
    override func number(from string: String) -> NSNumber? {
        // if string is format of mm:ss.nnn or nnn.nnn return the equivalent number of seconds
        var good = string.range(of: #"^(([0-5])?[0-9]:)?([0-5])?[0-9].[0-9]{0,3}$"#, options: .regularExpression) != nil // true
        
        if good { // parse the string as the number of seconds
            let comp = string.components(separatedBy: ":")
            var seconds:Double = 0
            if comp.count == 2 {
                seconds = Double(comp[0])! * 60 + Double(comp[1])!
            } else {
                seconds = Double(comp[0])!
            }
            return NSNumber(value: seconds)
        }
        
        // still here? try this:
        good = string.range(of:#"^[0-9]{0,3}.[0-9]{0,3}$"#, options: .regularExpression) != nil
        if good {
            return NSNumber(value: Double(string) ?? 0)
        }
        
        // still here? i got nothin
        return nil
    }
}



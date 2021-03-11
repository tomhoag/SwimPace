//
//  PoolViewController.swift
//  SwimPace
//
//  Created by Tom on 2/19/21.
//

import Cocoa
import AVFoundation

enum LayerName:String, CaseIterable {
    case corner = "CORNER"
    case dragpad = "DRAGPAD"
    case edge = "EDGE"
    case video = "VIDEO"
    case edgetext = "EDGETEXT"
    case paceline = "PACELINE"
}

enum TrackingAreaDictionaryKeys: String {
    case dragPadIndex = "dragPadIndex"
}

class PoolViewController: NSViewController, CameraFeedDelegate, ConfigControllerDelegate {
      
    var showPaceBarToken: NSKeyValueObservation?
    var showTitleBarToken: NSKeyValueObservation?
    var poolOutlineVisibleToken: NSKeyValueObservation?
    var cameraInfoToken: NSKeyValueObservation?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var raceTimer:Timer?
    private var poolEdge:PoolEdge = PoolEdge(CGRect.zero)
    
    let fps:Double = 30.0
    
    private var elapsedTime = 0.0
    
    var config:Config = Config()
    var cameraFeed:CameraFeed = CameraFeed()
    var cameras = [CameraInfo]()
    
    // MARK: - View Management
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.cameraFeed.delegate = self
        self.view.wantsLayer = true
        
        observe(config: self.config)
        setupCameraMenu()
        setupConfigMenu()
        
        poolEdge = PoolEdge(self.view.layer!.bounds.insetBy(dx:100, dy:100))
        
    }
    
    func createCamerasMenu() -> [NSMenuItem] {
        self.cameraFeed.refreshAvailableCameras()
        var menuItems = [NSMenuItem]()
        
        self.cameraFeed.availableCameras.forEach {
            let itm = NSMenuItem(title: ($0).displayName, action: #selector(applyCamera(_:)), keyEquivalent: "")
            itm.identifier = NSUserInterfaceItemIdentifier(rawValue: ($0).id)
            menuItems.append(itm)
        }
        
        menuItems.append(NSMenuItem.separator())
        menuItems.append(NSMenuItem(title: "Refresh List", action: #selector(refreshCameraList(_:)), keyEquivalent: ""))
        menuItems.append(NSMenuItem(title: "Load From File", action: #selector(loadFromFile(_:)), keyEquivalent: ""))
        return menuItems
    }
    
    func createConfigMenu() -> [NSMenuItem] {
        let item = NSMenuItem(title: "Pool & Race", action: #selector(showConfigSheet(_:)), keyEquivalent: "")
        let start = NSMenuItem(title: "Start", action: #selector(startRace(_:)), keyEquivalent: "")
        let pb = NSMenuItem(title: "Pace Bar Visible", action: #selector(paceBarVisibile(_ :)), keyEquivalent: "")
        let outline = NSMenuItem(title:"Show Pool Outline", action: #selector(poolOutline(_:)), keyEquivalent: "")
        let reset = NSMenuItem(title:"Reset Pool Outline", action: #selector(resetPoolOutline(_: )), keyEquivalent: "")
        return [item, start, pb, outline, reset]
    }
    
    @objc func showConfigSheet(_ sender: NSMenuItem) {
        guard let _ = sender.identifier else { return }
        
        let cvc = NSStoryboard(name: "Main", bundle: nil).instantiateController(identifier: "ConfigViewController") as ConfigController
        
        cvc.config = self.config
        cvc.delegate = self
        self.presentAsSheet(cvc)
    }
    
    @objc func startRace(_ sender:NSMenuItem) {
        guard let _ = sender.identifier else { return }
        self.raceStarted = true
    }
    
    @objc func poolOutline(_ sender: NSMenuItem) {
        guard let _ = sender.identifier else { return }
        self.config.showPoolOutline = !self.config.showPoolOutline
        sender.state = self.config.showPoolOutline ? .on : .off
    }
    
    @objc func resetPoolOutline(_ sender:NSMenuItem) {
        guard let _ = sender.identifier else { return }
        self.poolEdge = PoolEdge(self.view.layer!.bounds.insetBy(dx:100, dy:100))
        drawPoolLayers()
    }
    
    @objc func paceBarVisibile(_ sender: NSMenuItem) {
        guard let _ = sender.identifier else { return }
        self.config.showPaceBar = !self.config.showPaceBar
        sender.state = self.config.showPaceBar ? .on : .off
    }
    
    func didClose(_ configController: ConfigController) {
        self.dismiss(configController)
    }
    
    func setupConfigMenu() {
        guard let mainMenu = (NSApp.delegate as? AppDelegate)?.mainMenu else { return }
        guard let configMenu = mainMenu.item(withTitle: "Config") else { return }
        configMenu.submenu?.removeAllItems()
        let configItems = createConfigMenu()
        configItems.forEach { configMenu.submenu?.addItem($0) }
    }
    
    @objc func applyCamera(_ sender: NSMenuItem) {
        guard let _ = sender.identifier else { return }
        guard let mainMenu = (NSApp.delegate as? AppDelegate)?.mainMenu else { return }
        guard let camerasMenuItem = mainMenu.item(withTitle: "Video Input") else { return }
        
        // clear all of the check marks
        camerasMenuItem.submenu?.items.forEach { ($0).state = .off}
        // and check this camera
        sender.state = .on
                
        self.view.window!.title = "Pool View (\(sender.title))"
        
        // assign the selected device name to the pool view controller
        self.config.cameraInfo =  CameraInfo(id: sender.identifier!.rawValue, displayName: sender.title)
    }
    
    @objc func refreshCameraList(_ sender: NSMenuItem) {
        
    }
    
    @objc func loadFromFile(_ sender: NSMenuItem) {
        
        let dialog = NSOpenPanel();
        
        dialog.title                   = "Choose a video";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseDirectories = false;
        dialog.allowedFileTypes        = ["mp4"];
        
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                let path: String = result!.path
                playFile(at:path);
                // resize the window
                self.view.window!.title = path
            }
        } else {
            return // User clicked on "Cancel"
        }
    }
    
    func setupCameraMenu() {
        guard let mainMenu = (NSApp.delegate as? AppDelegate)?.mainMenu else { return }
        guard let camerasMenuItem = mainMenu.item(withTitle: "Video Input") else { return }
        camerasMenuItem.submenu?.removeAllItems()
        let cameraItems = createCamerasMenu()
        
        cameraItems.forEach { camerasMenuItem.submenu?.addItem($0) }
    }
    
    
    private func updateCameraSources() { // UNUSED???
        self.cameraFeed.refreshAvailableCameras()
        DispatchQueue.main.async {
            // empty the cameras array?
            var menuItems = [NSMenuItem]()
            
            
            self.cameraFeed.availableCameras.forEach {
                self.cameras.append($0)
                menuItems.append(NSMenuItem(title: ($0).displayName, action: nil, keyEquivalent: "x"))
            }
        }
    }
    
    func observe(config: Config) {
        self.config = config
        
        showPaceBarToken = config.observe(\.showPaceBar, options:.new) { (config, change) in
            guard let show = change.newValue else { return }
            if show == false {
                DispatchQueue.main.async {
                    self.clearPaceBar()
                }
            }
        }
        
        showTitleBarToken = config.observe(\.windowTitleBarVisible, options:.new) { (config, change) in
            guard let show = change.newValue else { return }
            DispatchQueue.main.async {
                if show {
                    self.view.window?.styleMask = [.resizable, .titled, .closable, .miniaturizable, .fullSizeContentView]
                } else {
                    self.view.window?.styleMask = [.resizable, .closable, .miniaturizable, .fullSizeContentView]
                }
            }
        }
        
        poolOutlineVisibleToken = config.observe(\.showPoolOutline, options:.new) { (config, change) in
            guard let show = change.newValue else { return }
            
            show ? self.drawPoolLayers() : self.clearPoolLayers()
        }
        
        cameraInfoToken = config.observe(\.cameraInfo, options:.new) { (config, change) in
            guard let cameraInfo = change.newValue else { return }
            
            self.cameraFeed.stopCaptureSession()
            self.cameraFeed = CameraFeed() // This is a hack -- should be able to re-use the existing?
            self.cameraFeed.delegate = self
            
            self.cameraFeed.device = self.cameraFeed.deviceFor(cameraInfo.id )
            self.cameraFeed.startCaptureSession()
            self.displayPreviewLayer()
        }
    }
    
    deinit {
        showPaceBarToken?.invalidate()
        showTitleBarToken?.invalidate()
        poolOutlineVisibleToken?.invalidate()
        cameraInfoToken?.invalidate()
    }
    
    var raceStarted:Bool  = false {
        didSet {
            if raceStarted {
                DispatchQueue.global(qos: .background).async {
                    self.raceTimer = Timer.scheduledTimer(withTimeInterval: 1/self.fps, repeats: true) { (timer) in
                        
                        self.elapsedTime = self.elapsedTime + 1.0 / self.fps
                        
                        if self.elapsedTime > Double(self.config.raceQualifyingTime) {
                            self.config.showPaceBar = false
                            return
                        }
                        
                        //guard self.config?.showPaceBar else { return }
                        
                        // update the pace line
                        if self.config.showPaceBar {
                            self.calcPaceLine(elapsedTime: CGFloat(self.elapsedTime))
                        }
                    }
                    RunLoop.current.run()
                }
            } else {
                raceTimer?.invalidate()
                self.elapsedTime = 0.0
                self.config.showPaceBar = false
            }
        }
    }
    
    // MARK: - Show Video
    
    var imageGenerator:AVAssetImageGenerator?
    var player:AVPlayer?
    var timeObserverToken:Any?
    
    func playFile(at path:String) {
        
        clearPoolLayer(named: .video)
        
        let asset = AVAsset(url: URL(fileURLWithPath: path))
        let tracks = asset.tracks(withMediaType: .video)
        let size = tracks[0].naturalSize
        
        self.view.frame = CGRect(x:0, y:0, width:size.width, height:size.height)
        self.view.window?.setContentSize(CGSize(width: size.width, height: size.height))
        
        let videoURL = NSURL(fileURLWithPath: path)
        player = AVPlayer(url: videoURL as URL)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.view.bounds
        playerLayer.name = LayerName.video.rawValue
        
        self.view.layer!.addSublayer(playerLayer)
        player?.play()
        
        if poolEdge.pointFor(poolCorner:.startLeft) == poolEdge.pointFor(poolCorner:.startRight) {
            poolEdge = PoolEdge(self.view.layer!.bounds.insetBy(dx:100, dy:100))
        }
        
        self.poolEdge = PoolEdge(self.view.layer!.bounds.insetBy(dx:100, dy:100))

        self.drawPoolLayers()
        config.showPoolOutline = true
        
        imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator!.requestedTimeToleranceAfter = CMTime.zero
        imageGenerator!.requestedTimeToleranceBefore = CMTime.zero
        
        if let player = player {
            let interval = CMTime(seconds: 1/fps, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            // TODO: which queue??
            timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue:.global(qos: .background), using: { _ in
                if self.dragging {
                    self.layerImage = self.imageFromPlayer()
                }
            })
        }
    }
    
    func imageFromPlayer() -> CGImage? {
        guard let imageGenerator = self.imageGenerator, let player = self.player else { return nil }
        let cgImage: CGImage = try! imageGenerator.copyCGImage(at: player.currentTime(), actualTime: nil)
        return cgImage
    }
    
    func displayPreviewLayer() {
        
        DispatchQueue.main.async {
            
            self.clearPoolLayer(named: .video)
            
            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.cameraFeed.captureSession)
            self.previewLayer?.videoGravity = .resizeAspectFill
            self.previewLayer?.name = LayerName.video.rawValue
            
            let captureInput = self.cameraFeed.device
            let dims : CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(captureInput!.activeFormat.formatDescription)
            
            self.view.window?.setContentSize(CGSize(width: Int(dims.width), height: Int(dims.height)))
            
            self.view.frame = CGRect(x: 0, y: 0, width: Int(dims.width), height: Int(dims.height))
            self.previewLayer?.frame = self.view.bounds
            self.view.layer?.insertSublayer(self.previewLayer!, at: 0)
            
            self.poolEdge = PoolEdge(self.view.layer!.bounds.insetBy(dx:100, dy:100))
            
            self.config.showPoolOutline = true
            self.drawPoolLayers()
        
        }
    }
    
    // MARK: - drawing the pool edge and pace bar
    
    func drawDraggingDragPad() {
        guard dragging, let image = layerImage else { return }
        clearPoolLayer(named: .dragpad)
        let shape = poolEdge.layerForMagnifingDragPad(padIndex: dragPadIndex, in: view.frame, name: .dragpad, image: image)
        view.layer?.addSublayer(shape)
    }
    
    func drawDragPads() {
        clearPoolLayer(named: .dragpad)
        guard dragging else { return }
        if let image = layerImage {
            PoolEdge.DragPadIndex.allCases.forEach {
                let shape = poolEdge.layerForMagnifingDragPad(padIndex: $0, in: view.frame, name: .dragpad, image: image)
                view.layer?.addSublayer(shape)
            }
        }
    }
    
    func drawPoolCorners() {
        clearPoolLayer(named: .corner)
        
        PoolEdge.PoolCorner.allCases.forEach {
            self.view.layer?.addSublayer(self.poolEdge.shapeLayerForCorner(corner: $0, in: self.view.frame, name: .corner))
        }
    }
    
    func drawPoolEdge() {
        clearPoolLayer(named: .edge)
        let shape = poolEdge.shapeLayerPoolEdges(in: self.view.frame, name:.edge)
        self.view.layer?.addSublayer(shape)
        
        self.view.layer?.addSublayer(poolEdge.textLayerForPoolEdges(in: self.view.frame, name: .edgetext))
    }
    
    func clearPoolLayer(named:LayerName) {
        guard let layer = self.view.layer, let sublayers = layer.sublayers else { return }
        sublayers.forEach {
            if ($0).name == named.rawValue {
                ($0).removeFromSuperlayer()
            }
        }
    }
    
    func clearPoolLayers() {
        clearPoolLayer(named: .edge)
        clearPoolLayer(named: .corner)
        clearPoolLayer(named: .dragpad)
        clearPoolLayer(named: .edgetext)
    }
    
    // MARK: - Pace Line
    
    func clearPaceBar() {
        self.clearPoolLayer(named: .paceline)
    }
    
    func drawPoolLayers() {
        clearPoolLayers()
        
        drawDraggingDragPad()
        drawPoolEdge()
        drawPoolCorners()
        
        if !dragging {
            addTrackingAreas()
        }
    }
    
    func calcPaceLine(elapsedTime:CGFloat) {
        
        let qualifyPace:CGFloat = CGFloat(self.config.raceDistance) / CGFloat(self.config.raceQualifyingTime) //raceLength / qualifyTime
        
        var distanceSwam:CGFloat = elapsedTime * qualifyPace
        
        if distanceSwam > CGFloat(self.config.poolLength) {
            
            let partialLengthSwam = distanceSwam.truncatingRemainder(dividingBy: CGFloat(self.config.poolLength))
            let lengthsSwam = Int(elapsedTime * qualifyPace / CGFloat(self.config.poolLength))
            
            if lengthsSwam % 2 == 0 {
                distanceSwam = partialLengthSwam
            } else {
                distanceSwam = CGFloat(self.config.poolLength) - partialLengthSwam
            }
        }
        
        let t = distanceSwam / CGFloat(self.config.poolLength)
        let startRight = poolEdge.pointFor(poolCorner: .startRight)
        let startLeft = poolEdge.pointFor(poolCorner: .startLeft)
        let turnRight = poolEdge.pointFor(poolCorner: .turnRight)
        let turnLeft = poolEdge.pointFor(poolCorner: .turnLeft)
        
        // Line(leftPoint, rightPoint) is the pace line
        var paceLineRight = CGPoint.zero
        paceLineRight.x = ((1.0 - t) * startRight.x) + (t * turnRight.x)
        paceLineRight.y = ((1.0 - t) * startRight.y) + (t * turnRight.y)
        
        var paceLineLeft = CGPoint.zero
        paceLineLeft.x = ((1.0 - t) * startLeft.x) + (t * turnLeft.x)
        paceLineLeft.y = ((1.0 - t) * startLeft.y) + (t * turnLeft.y)
        
        // calculate the corners of the pace bar by using the proportion of the edges of the triangles
        let bd:CGFloat = CGFloat(self.config.paceBarWidth)/2.0
        let deltaT = sqrt((paceLineRight.x - startRight.x) * (paceLineRight.x - startRight.x) +
                            (paceLineRight.y - startRight.y) * (paceLineRight.y - startRight.y))
        
        var ac = paceLineRight.x - poolEdge.pointFor(poolCorner: .startRight).x
        var bc = paceLineRight.y - poolEdge.pointFor(poolCorner: .startRight).y
        var be = bd * ac / deltaT
        var de = bc * bd / deltaT
        let deltaRight = CGPoint(x: paceLineRight.x + be, y: paceLineRight.y + de)
        let deltaRight2 = CGPoint(x: paceLineRight.x - be, y: paceLineRight.y - de)
        
        ac = paceLineLeft.x - poolEdge.pointFor(poolCorner: .startLeft).x
        bc = paceLineLeft.y - poolEdge.pointFor(poolCorner: .startLeft).y
        be = bd * ac / deltaT
        de = bc * bd / deltaT
        let deltaLeft = CGPoint(x: paceLineLeft.x + be, y: paceLineLeft.y + de)
        let deltaLeft2 = CGPoint(x: paceLineLeft.x - be, y: paceLineLeft.y - de)
        
        DispatchQueue.main.async {
            self.drawPaceBar(left: deltaLeft2, left2: deltaLeft, right: deltaRight2, right2:deltaRight, in: self.view.frame )
        }
    }
    
    
    func drawPaceBar(left:CGPoint, left2:CGPoint, right:CGPoint, right2:CGPoint, in frame: CGRect) {
        
        clearPaceBar()
        
        let pacebar = CAShapeLayer()
        pacebar.frame = frame
        var path = CGMutablePath()
        path.move(to:left)
        path.addLine(to: left2)
        path.addLine(to: right2)
        path.addLine(to: right)
        path.closeSubpath()
        pacebar.path = path
        pacebar.fillColor = self.config.paceBarColor.cgColor.copy(alpha: 0.5)
        pacebar.name = LayerName.paceline.rawValue //"paceLine"
        self.view.layer?.addSublayer(pacebar)
        
        let paceline = CAShapeLayer()
        paceline.frame = frame
        path = CGMutablePath()
        path.move(to:left.midpointBetween(left2))
        path.addLine(to:right.midpointBetween(right2))
        paceline.path = path
        paceline.strokeColor = self.config.paceBarColor.cgColor
        paceline.name = LayerName.paceline.rawValue
        self.view.layer?.addSublayer(paceline)
        
        let textLayer = CATextLayer()
        let width = left.distanceToPoint(right)
        textLayer.fontSize = 24
        textLayer.frame = CGRect(x: 0, y:0, width: width, height: textLayer.fontSize * 1.25)
        textLayer.position = CGPoint(x:right2.x, y:right2.y)
        textLayer.alignmentMode = .center
        textLayer.anchorPoint = CGPoint(x:0, y: 1)
        
        let angle = right2.angleBetweenPoints(firstPoint: left2, secondPoint: CGPoint(x:10000000, y:right2.y))
        let rotate = CGAffineTransform(rotationAngle: angle)
        textLayer.transform = CATransform3DMakeAffineTransform(rotate)
        
        textLayer.string = self.config.paceBarString
        textLayer.foregroundColor = self.config.paceBarStringColor.cgColor
        
        textLayer.name = LayerName.paceline.rawValue
        self.view.layer?.addSublayer(textLayer)
    }
    
    // MARK: - mouse stuff
    
    // add tracking areas so that we receive mouseEnter and mouseExit events
    func addTrackingAreas() {
        removeTrackingAreas()
        poolEdge.trackingAreas(owner:self).forEach { self.view.addTrackingArea($0) }
    }
    
    func removeTrackingAreas() {
        self.view.trackingAreas.forEach { self.view.removeTrackingArea($0) }
    }
    
    override func mouseEntered(with event: NSEvent) {
        
        guard config.showPoolOutline else { return }
        guard let trackingArea = event.trackingArea else { return }
        
        if let dict = trackingArea.userInfo, let padIndex = dict[TrackingAreaDictionaryKeys.dragPadIndex.rawValue] as? PoolEdge.DragPadIndex {
            let layer = poolEdge.shapeLayerForDragPad(padIndex: padIndex, frame: self.view.frame, name: .dragpad)
            self.view.layer?.addSublayer(layer)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        clearPoolLayer(named: .dragpad )
    }
    
    private var dragging:Bool = false
    private var lastDraggingPoint:CGPoint = CGPoint.zero
    private var dragPadIndex:PoolEdge.DragPadIndex = .leftBegin
    
    override func mouseDown(with event: NSEvent) {

        (dragging, dragPadIndex) = poolEdge.isPointContainedByAnyDragPad(event.locationInWindow)
        if dragging {
            lastDraggingPoint = event.locationInWindow
            removeTrackingAreas()
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard dragging else { return }
        
        var dx = lastDraggingPoint.x - event.locationInWindow.x
        var dy = lastDraggingPoint.y - event.locationInWindow.y
        
        // would the new endpoint still be on screen?
        let frame = self.view.window!.contentRect(forFrameRect: self.view.window!.frame)
        let (onScreen, adj) = poolEdge.updatedEdgeInView(dragPadIndex: dragPadIndex, offset:CGSize(width: dx, height: dy), frame: frame)
        
        if !(onScreen) {
            dx = dx - adj.width
            dy = dy - adj.height
        }

        poolEdge.updateEdge(dragPadIndex: dragPadIndex, offset: CGSize(width: dx, height: dy))
        lastDraggingPoint = event.locationInWindow
        drawPoolLayers()
    }
    
    override func mouseUp(with event: NSEvent) {
        guard dragging else { return }
        dragging = false
        drawPoolLayers()
    }

    private var layerImage:CGImage? // this is the image that the camera and the AVPlayer use for the maginified image

}

// MARK: - CameraFeedDelegate

extension PoolViewController {
    func cameraFeed(_ cameraFeed: CameraFeed, didStartRunningCaptureSession captureSession: AVCaptureSession) {
        //        print("didStartRunningCaptureSession")
    }
    
    func cameraFeed(_ cameraFeed: CameraFeed, didStopRunningCaptureSession captureSession: AVCaptureSession) {
        //        print("didStopRunningCaptureSession")
    }
    
    
    func cameraFeed(_ cameraFeed: CameraFeed, didUpdateWithSampleBuffer sampleBuffer: CMSampleBuffer) {
        //        print("didUpdateWithSampleBuffer")
        
        if dragging {
            layerImage = getImageFromSampleBuffer(sampleBuffer: sampleBuffer)
        }
        
        //        elapsedTime = elapsedTime + 1.0 / fps
        //
        //        if elapsedTime > Double(qualifyTime) {
        //            showPaceBar = false
        //            return
        //        }
        //
        //        guard showPaceBar else { return }
        //
        //        // update the pace line
        //        self.calcPaceLine(elapsedTime: CGFloat(elapsedTime))
        
        //        print("didUpdateWithSampleBuffer")
        
    }
    
    func cameraFeed(_ cameraFeed: CameraFeed, didFailWithError error: Error) {
        print("didFailWithError")
    }
    
    func getImageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            return nil
        }
        guard let cgImage = context.makeImage() else {
            return nil
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        return cgImage
        
    }
}

extension CGPoint {
    
    static func angleBetweenThreePoints(center: CGPoint, firstPoint: CGPoint, secondPoint: CGPoint) -> CGFloat {
        let firstAngle = atan2(firstPoint.y - center.y, firstPoint.x - center.x)
        let secondAngle = atan2(secondPoint.y - center.y, secondPoint.x - center.x)
        var radians = firstAngle - secondAngle
        
        while radians < 0 {
            radians += 2 * CGFloat.pi
        }
        
        while radians > 2 * CGFloat.pi {
            radians -= 2 * CGFloat.pi
        }
        
        return radians
    }
    
    func angleBetweenPoints(firstPoint: CGPoint, secondPoint: CGPoint) -> CGFloat {
        return CGPoint.angleBetweenThreePoints(center: self, firstPoint: firstPoint, secondPoint: secondPoint)
    }
    
    func distanceToPoint(_ otherPoint: CGPoint) -> CGFloat {
        return sqrt(pow((otherPoint.x - x), 2) + pow((otherPoint.y - y), 2))
    }
    
    func midpointBetween(_ other: CGPoint) -> CGPoint {
        return CGPoint(x: (self.x + other.x) / 2.0,
                       y: (self.y + other.y) / 2.0)
    }
}


extension NSWindow {
    var titlebarHeight: CGFloat {
        frame.height - contentRect(forFrameRect: frame).height
    }
}




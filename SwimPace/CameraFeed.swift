//
//  CameraFeed.swift
//  SwimCutLine
//
//  Created by Tom on 2/16/21.
//

import Foundation
import CoreImage
import AVFoundation
import Cocoa
import SwiftUI

private let SessionQueueLabel = "com.FaceDetection.camera.capture_session"
private let SampleBufferQueueLabel = "com.FaceDetection.camera.sample_buffer"

protocol CameraFeedDelegate {
    func cameraFeed(_ cameraFeed: CameraFeed, didStartRunningCaptureSession captureSession: AVCaptureSession)
    func cameraFeed(_ cameraFeed: CameraFeed, didStopRunningCaptureSession captureSession: AVCaptureSession)
    func cameraFeed(_ cameraFeed: CameraFeed, didUpdateWithSampleBuffer sampleBuffer: CMSampleBuffer)
    func cameraFeed(_ cameraFeed: CameraFeed, didFailWithError error: Error)
}

@objc class CameraInfo:NSObject { //}: Hashable {
    static func == (lhs: CameraInfo, rhs: CameraInfo) -> Bool {
        return true
    }
    
    init(id: String, displayName:String) {
        self.id = id
        self.displayName = displayName
    }
    
    @objc dynamic var id: String
    @objc dynamic var displayName: String
}

class CameraFeed: NSObject, ObservableObject, Identifiable {
    // Use this queue for asynchronous calls to the capture session.
    fileprivate let sessionQueue = DispatchQueue(label: SessionQueueLabel, attributes: [])
    
    // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information
    fileprivate let outputQueue = DispatchQueue(label: SampleBufferQueueLabel, attributes: [])
    
    // Domain name for errors.
    static let errorDomain = "com.FaceDetection.CameraFeed.ErrorDomain"
    
    // Possible error types.
    enum Error : Swift.Error {
        case noCamera
        case failedToAddInput
        case failedToAddOutput
        case failedToSetVideoOrientation
    }
    
    var availableCameras = [CameraInfo]()
    
    var device: AVCaptureDevice?
    
    var input: AVCaptureDeviceInput? = nil
    var delegate: CameraFeedDelegate? = nil
    
    //var previewLayer: AVCaptureVideoPreviewLayer?
    
    let captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        return session
    }()
    
    let videoDataOutput: AVCaptureVideoDataOutput = {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [ kCVPixelBufferPixelFormatTypeKey as String: Int(kCMPixelFormat_32BGRA) ]
        output.alwaysDiscardsLateVideoFrames = true
        return output
    }()
    
    fileprivate(set) var isSessionRunning = false {
        didSet {
            switch isSessionRunning {
            case true: self.delegate?.cameraFeed(self, didStartRunningCaptureSession: captureSession)
            case false: self.delegate?.cameraFeed(self, didStopRunningCaptureSession: captureSession)
            }
        }
    }
    
    fileprivate var isSessionConfigured = false
    
    override init() {
        super.init()
        refreshAvailableCameras()
    }
    
    func refreshAvailableCameras() {
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.externalUnknown, .builtInWideAngleCamera], mediaType: .video, position: .front)
        let devices = discoverySession.devices
        
        self.availableCameras = [CameraInfo]()
        if devices.count > 0 {
            devices.enumerated().forEach{ (i,_) in
                let ci = CameraInfo(id: devices[i].uniqueID, displayName: devices[i].localizedName)
                self.availableCameras.append(ci)
            }
        }
    }
    
    func deviceFor(_ deviceID:String) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.externalUnknown, .builtInWideAngleCamera], mediaType: .video, position: .front)
        let devices = discoverySession.devices
        
        let device = devices.first(where: {$0.uniqueID == deviceID})
        return device
    }
    
    func startCaptureSession() {
        if isSessionRunning {
//    completion()
            return
        }
        
        sessionQueue.async { [weak self] in
            // Do nothing if self has been deallocated.
            guard self != nil else { return }
            
            // Configure the capture session if it has not yet been configured.
            if let controller = self, !controller.isSessionConfigured {
                do {
                    try controller.configureCaptureSession()
                }
                catch {
                    controller.delegate?.cameraFeed(controller, didFailWithError: error)
                }
            }
            
            // Start the session!
            self?.captureSession.startRunning()
            self?.isSessionRunning = true
//            completion()
        }
    }
    
    func stopCaptureSession() {
        if !isSessionRunning {
            //completion()
            return
        }
        
        sessionQueue.async { [weak self] in
            guard self != nil else { return }
            self?.captureSession.stopRunning()
            self?.isSessionRunning = false
            //completion()
        }
    }
    
    fileprivate func configureCaptureSession() throws {
        guard let device = device else {
            throw Error.noCamera
        }
        
        // Grab the input for this device.
        let input = try AVCaptureDeviceInput(device: device)
        
        // Assign our input, to remember it for future use.
        self.input = input
        
        // Set the sample buffer delegate of the video data output to self
        videoDataOutput.setSampleBufferDelegate(self, queue: outputQueue)
        
        // Begin configuring the session...
        captureSession.beginConfiguration()
        
        // Add input if possible.
        guard captureSession.canAddInput(input) == true else {
            throw Error.failedToAddInput
        }
        captureSession.addInput(input)
        
        // Add the video data output to the capture session if possible
        guard captureSession.canAddOutput(videoDataOutput) == true else {
            throw Error.failedToAddOutput
        }
        captureSession.addOutput(videoDataOutput)
        
        // Assign a device orientation to the video data output.
        guard let connection = videoDataOutput.connection(with: .video) else {
            throw Error.failedToSetVideoOrientation
        }
        connection.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
        
        // Finish configuring the session.
        captureSession.commitConfiguration()
        
        // That's it. Configured.
        isSessionConfigured = true
    }
    
    enum CameraControllerError: Swift.Error {
       case captureSessionAlreadyRunning
       case captureSessionIsMissing
       case inputsAreInvalid
       case invalidOperation
       case noCamerasAvailable
       case unknown
    }
    
}

extension CameraFeed : AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.cameraFeed(self, didUpdateWithSampleBuffer: sampleBuffer)
    }
}


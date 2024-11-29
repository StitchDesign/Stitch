//
//  CameraFeedActor.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 3/1/24.
//

import AVFoundation
import Foundation
import SwiftUI
import UIKit
import StitchSchemaKit
import ARKit

final actor CameraFeedActor {
    @MainActor weak var bufferDelegate: CaptureSessionBufferDelegate?
    private let context = CIContext()

    @MainActor weak var imageConverterDelegate: ImageConverterDelegate?
    
    @MainActor var authStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: CAMERA_FEED_MEDIA_TYPE)
    }

    @MainActor
    func configureSession(session: StitchCameraSession,
                          device: StitchCameraDevice,
                          position: AVCaptureDevice.Position,
                          cameraOrientation: StitchCameraOrientation,
                          startCameraCallback: @escaping () -> ()) {
        guard authStatus == .authorized else {
            return
        }

        // Must call on main thread or AR may crash
        session.configureSession(
            device: device,
            position: position,
            cameraOrientation: cameraOrientation)
        
        startCameraCallback()
    }

    @MainActor func startCamera(session: StitchCameraSession,
                     device: StitchCameraDevice,
                     position: AVCaptureDevice.Position,
                     cameraOrientation: StitchCameraOrientation,
                     startCameraCallback: @escaping () -> ()) {
        let authStatus = self.authStatus
        switch authStatus {
        case .authorized:
            self.configureSession(
                session: session,
                device: device,
                position: position,
                cameraOrientation: cameraOrientation,
                startCameraCallback: startCameraCallback)

        case .notDetermined:
            self.requestPermission(session: session,
                                   device: device,
                                   position: position,
                                   cameraOrientation: cameraOrientation,
                                   startCameraCallback: startCameraCallback)
        default:
            DispatchQueue.main.async {
                dispatch(CameraPermissionDeclined())
            }
        }
    }

    @MainActor
    private func requestPermission(session: StitchCameraSession,
                                   device: StitchCameraDevice,
                                   position: AVCaptureDevice.Position,
                                   cameraOrientation: StitchCameraOrientation,
                                   startCameraCallback: @escaping () -> ()) {
        AVCaptureDevice.requestAccess(for: CAMERA_FEED_MEDIA_TYPE) { isGranted in
            if isGranted {
                self.startCamera(
                    session: session,
                    device: device,
                    position: position,
                    cameraOrientation: cameraOrientation,
                    startCameraCallback: startCameraCallback)
            }
        }
    }

    func createUIImage(from sampleBuffer: CMSampleBuffer) async {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // Save processed image somewhere so that the UIImage can be retained when main thread dispatch
        // is called. Otherwise the resource might release from memory.
        guard let newImage = self.createUIImage(from: ciImage,
                                                context: context) else {
            return
        }
        
        await MainActor.run { [weak self, weak newImage] in
            guard let newImage = newImage else { return }
            
            self?.imageConverterDelegate?.imageConverted(image: newImage)
        }
    }
    
    func createUIImage(from frame: ARFrame,
                       iPhone: Bool) async {
        let image = frame.capturedImage
        let ciImage = CIImage(cvImageBuffer: image)

        // Send image to graph if successfully created
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        // Rotate image on iPhone
        let uiImage = iPhone ? UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            : UIImage(cgImage: cgImage)
        
        await MainActor.run { [weak self] in
            self?.imageConverterDelegate?.imageConverted(image: uiImage)
        }
    }
    
    func createUIImage(from ciImage: CIImage,
                       context: CIContext) -> UIImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let uiImage = UIImage(cgImage: cgImage)
        return  uiImage
    }
    
    // https://developer.apple.com/documentation/avfoundation/avcapturesession
    static func configureSession(session: AVCaptureSession,
                                 device: StitchCameraDevice,
                                 position: AVCaptureDevice.Position,
                                 cameraOrientation: StitchCameraOrientation,
                                 deviceType: UIUserInterfaceIdiom,
                                 bufferDelegate: CaptureSessionBufferDelegate) {
        
        session.beginConfiguration()

        // NOTE: perf-wise, we seem to be fine to not limit the image-size and -quality.
        //            self.sessionPreset = .vga640x480
        //            self.sessionPreset = .medium

        let videoOutput = AVCaptureVideoDataOutput()

        guard let cameraDevice = device.device,
              let captureDeviceInput = try? AVCaptureDeviceInput(device: cameraDevice),
              session.canAddInput(captureDeviceInput),
              session.canAddOutput(videoOutput) else {
            log("FrameExtractor error: could not setup input or output.")
            session.commitConfiguration() // commit configuration if we must exit
            return
        }

        session.addInput(captureDeviceInput)
        videoOutput.setSampleBufferDelegate(bufferDelegate, queue: DispatchQueue(label: "sample buffer"))

        session.addOutput(videoOutput)

        guard let connection: AVCaptureConnection = videoOutput.connection(with: CAMERA_FEED_MEDIA_TYPE) else {
            log("FrameExtractor: configureSession: Cannot establish connection")
            session.commitConfiguration()
            return
        }

        // `StitchAVCaptureSession` is only used for devices / camera directions that DO NOT support Augmented Reality
        // e.g. Mac device, or iPad with front camera direction
        let isIPhone = deviceType == .phone
        let isIPad = deviceType == .pad

        if isIPhone {
            connection.videoRotationAngle = 90
        }
        //Matches default behavior on Main
        //TODO: Support rotation during session
        else if isIPad {
            connection.videoRotationAngle = 180
        } else if let rotationAngle = Self.getCameraRotationAngle(
            device: device,
            cameraOrientation: cameraOrientation) {
            connection.videoRotationAngle = rotationAngle
        }

        connection.isVideoMirrored = position == .front

        session.commitConfiguration()
    }
    
    private static func getCameraRotationAngle(device: StitchCameraDevice,
                                               cameraOrientation: StitchCameraOrientation) -> Double? {
            // Convert StitchCameraOrientation to rotation angle
            switch cameraOrientation.convertOrientation {
            case .portrait:
                return 0
            case .portraitUpsideDown:
                return 180
            case .landscapeRight:
                return 90
            case .landscapeLeft:
                return 270
            @unknown default:
                return nil
            }
        }
}

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

actor CameraFeedActor {
    private let context = CIContext()
//    var currentProcessedImage: UIImage?
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
        
        // Per compiler: should be called from background thread for AVCapture
        
        // TODO: explore this more
        
        startCameraCallback()
        
//        Task { [weak session] in
//            session?.startRunning()
//        }
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
//            Task { [weak self, weak session] in
//                if let _session = session,
                   if isGranted {
                    self.startCamera(
                        session: session,
                        device: device,
                        position: position,
                        cameraOrientation: cameraOrientation,
                        startCameraCallback: startCameraCallback)
//                }
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
        
//        self.currentProcessedImage = newImage
        
        await MainActor.run { [weak self] in
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
}

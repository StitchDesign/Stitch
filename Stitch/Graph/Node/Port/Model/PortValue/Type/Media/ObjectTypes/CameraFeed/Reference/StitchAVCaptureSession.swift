//
//  StitchAVCaptureSession.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/13/22.
//

@preconcurrency import AVFoundation
import Foundation
import StitchSchemaKit
import UIKit

/// Camera library used when AR is not available.
final class StitchAVCaptureSession: StitchCameraSession {
    let cameraSession: AVCaptureSession = .init()
    @MainActor let bufferDelegate: CaptureSessionBufferDelegate = .init()
    
    // we need to do some work asynchronously
    //    private let sessionQueue = DispatchQueue(label: "session queue")
    var actor: CameraFeedActor {
        bufferDelegate.actor
    }
    
    func stopRunning() {
        self.cameraSession.stopRunning()
    }
    
    var currentImage: UIImage?
    
//    let bufferDelegate: CaptureSessionBufferDelegate

    @MainActor
    init() {
        self.actor.imageConverterDelegate = self
//        self.bufferDelegate = CaptureSessionBufferDelegate()


        // .high: causes app to crash on device 'due to memory issues',
        // even though app's memory footprint is quite low;
        // profile in Instruments.

        // NOTE: perf-wise, we seem to be fine to not limit the image-size and -quality.
        //        self.sessionPreset = .medium
        //        self.sessionPreset = .vga640x480
    }

    // https://developer.apple.com/documentation/avfoundation/avcapturesession
    @MainActor func configureSession(device: StitchCameraDevice,
                                     position: AVCaptureDevice.Position,
                                     cameraOrientation: StitchCameraOrientation) {
        let deviceType = UIDevice.current.userInterfaceIdiom
        
        Task { [weak self] in
            guard let avCapture = self else { return }
            
            await avCapture.actor
                .configureSession(session: avCapture.cameraSession,
                                  device: device,
                                  position: position,
                                  cameraOrientation: cameraOrientation,
                                  deviceType: deviceType)
        }
    }
}

/// Delegate class for managing image buffer from `AVCaptureSession`.
final class CaptureSessionBufferDelegate: NSObject, Sendable, @preconcurrency AVCaptureVideoDataOutputSampleBufferDelegate {
//    private let context = CIContext()
//    @MainActor var convertedImage: UIImage?
//    private var isLoading: Bool = false
    let actor: CameraFeedActor = CameraFeedActor()
    
//    @MainActor var convertedImage: UIImage?
    
    @MainActor
    override init() {
        super.init()
        
        self.actor.bufferDelegate = self
    }
    
    // updated signature per this comment: https://medium.com/@b99705008/great-tutorial-it-really-help-me-to-understand-the-process-to-implement-a-camera-capture-feature-4baeadfe0d96
    @MainActor
    func captureOutput(_ captureOutput: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
//        guard !self.isLoading else { return }
//        self.isLoading = true
        
//        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
//            return
//        }
        
        Task(priority: .high) { [weak self] in
//            guard let sampleBuffer = sampleBuffer else { return }
            
            await self?.actor.createUIImage(from: sampleBuffer)
        }
    }
}

protocol ImageConverterDelegate: AnyObject {
    @MainActor
    func imageConverted(image: UIImage)
}

extension StitchAVCaptureSession: ImageConverterDelegate {
    func imageConverted(image: UIImage) {
        image.accessibilityIdentifier = CAMERA_DESCRIPTION
        
        self.currentImage = image
//        self.isLoading = false
        
        dispatch(RecalculateCameraNodes())
    }
}

struct RecalculateCameraNodes: GraphEvent {
    func handle(state: GraphState) {
        let cameraNodeIds = state.visibleNodesViewModel.nodes.values
            .filter { $0.kind == .patch(.cameraFeed) }
            .map { $0.id }
            .toSet
        
        guard !cameraNodeIds.isEmpty else {
            return
        }
        
        state.calculate(cameraNodeIds)
    }
}

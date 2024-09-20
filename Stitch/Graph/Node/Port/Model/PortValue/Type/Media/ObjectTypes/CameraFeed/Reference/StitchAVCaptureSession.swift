//
//  StitchAVCaptureSession.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/13/22.
//

import AVFoundation
import Foundation
import StitchSchemaKit
import UIKit

extension AVCaptureSession: @unchecked Sendable { }

/// Camera library used when AR is not available.
final class StitchAVCaptureSession: AVCaptureSession, StitchCameraSession {
    weak var actor: CameraFeedActor?
    
    @MainActor var currentImage: UIImage? {
        self.bufferDelegate.convertedImage
    }
    
    var bufferDelegate = CaptureSessionBufferDelegate()

    init(actor: CameraFeedActor) {
        super.init()

        self.actor = actor

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
        self.beginConfiguration()

        // NOTE: perf-wise, we seem to be fine to not limit the image-size and -quality.
        //            self.sessionPreset = .vga640x480
        //            self.sessionPreset = .medium

        let videoOutput = AVCaptureVideoDataOutput()

        guard let cameraDevice = device.device,
              let captureDeviceInput = try? AVCaptureDeviceInput(device: cameraDevice),
              self.canAddInput(captureDeviceInput),
              self.canAddOutput(videoOutput) else {
            log("FrameExtractor error: could not setup input or output.")
            self.commitConfiguration() // commit configuration if we must exit
            return
        }

        self.addInput(captureDeviceInput)
        videoOutput.setSampleBufferDelegate(self.bufferDelegate, queue: DispatchQueue(label: "sample buffer"))

        self.addOutput(videoOutput)

        guard let connection: AVCaptureConnection = videoOutput.connection(with: CAMERA_FEED_MEDIA_TYPE) else {
            log("FrameExtractor: configureSession: Cannot establish connection")
            self.commitConfiguration()
            return
        }

        // `StitchAVCaptureSession` is only used for devices / camera directions that DO NOT support Augmented Reality
        // e.g. Mac device, or iPad with front camera direction
        let isIPhone = UIDevice.current.userInterfaceIdiom == .phone
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad

        if isIPhone {
            connection.videoRotationAngle = 90
        }
        //Matches default behavior on Main
        //TODO: Support rotation during session
        else if isIPad {
            connection.videoRotationAngle = 180
        } else if let rotationAngle = self.getCameraRotationAngle(
            device: device,
            cameraOrientation: cameraOrientation) {
            connection.videoRotationAngle = rotationAngle
        }

        connection.isVideoMirrored = position == .front

        self.commitConfiguration()
    }

    @MainActor
    private func getCameraRotationAngle(device: StitchCameraDevice,
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

/// Delegate class for managing image buffer from `AVCaptureSession`.
final class CaptureSessionBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    private let context = CIContext()
    private var processedImage: UIImage?
    private var isLoading: Bool = false
    
    @MainActor var convertedImage: UIImage?
    
    // updated signature per this comment: https://medium.com/@b99705008/great-tutorial-it-really-help-me-to-understand-the-process-to-implement-a-camera-capture-feature-4baeadfe0d96
    func captureOutput(_ captureOutput: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        // Prevents image loading if we haven't yet updated main thread
        guard !self.isLoading else {
            return
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // Save processed image somewhere so that the UIImage can be retained when main thread dispatch
        // is called. Otherwise the resource might release from memory.
        self.processedImage = CameraFeedActor.createUIImage(from: ciImage,
                                                     context: context)
        self.isLoading = true
        
        DispatchQueue.main.async { [weak self] in
            guard let newImage = self?.processedImage else {
                return
            }
            
            self?.convertedImage = newImage
            self?.isLoading = false
            
            dispatch(RecalculateCameraNodes())
        }
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

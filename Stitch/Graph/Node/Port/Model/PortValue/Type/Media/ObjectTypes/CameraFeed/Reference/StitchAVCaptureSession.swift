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
    
    func stopRunning() {
        self.cameraSession.stopRunning()
    }
    
    @MainActor var currentImage: UIImage? {
        self.bufferDelegate.convertedImage
    }
    
    let bufferDelegate: CaptureSessionBufferDelegate

    @MainActor
    init(actor: CameraFeedActor) {
        self.bufferDelegate = CaptureSessionBufferDelegate()


        // .high: causes app to crash on device 'due to memory issues',
        // even though app's memory footprint is quite low;
        // profile in Instruments.

        // NOTE: perf-wise, we seem to be fine to not limit the image-size and -quality.
        //        self.sessionPreset = .medium
        //        self.sessionPreset = .vga640x480
    }

    // https://developer.apple.com/documentation/avfoundation/avcapturesession
    func configureSession(device: StitchCameraDevice,
                                     position: AVCaptureDevice.Position,
                                     cameraOrientation: StitchCameraOrientation) {
        self.cameraSession.beginConfiguration()

        // NOTE: perf-wise, we seem to be fine to not limit the image-size and -quality.
        //            self.sessionPreset = .vga640x480
        //            self.sessionPreset = .medium

        let videoOutput = AVCaptureVideoDataOutput()

        guard let cameraDevice = device.device,
              let captureDeviceInput = try? AVCaptureDeviceInput(device: cameraDevice),
              self.cameraSession.canAddInput(captureDeviceInput),
              self.cameraSession.canAddOutput(videoOutput) else {
            log("FrameExtractor error: could not setup input or output.")
            self.cameraSession.commitConfiguration() // commit configuration if we must exit
            return
        }

        self.cameraSession.addInput(captureDeviceInput)
        videoOutput.setSampleBufferDelegate(self.bufferDelegate, queue: DispatchQueue(label: "sample buffer"))

        self.cameraSession.addOutput(videoOutput)

        guard let connection: AVCaptureConnection = videoOutput.connection(with: CAMERA_FEED_MEDIA_TYPE) else {
            log("FrameExtractor: configureSession: Cannot establish connection")
            self.cameraSession.commitConfiguration()
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

        self.cameraSession.commitConfiguration()
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
final class CaptureSessionBufferDelegate: NSObject, @preconcurrency AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
//    private let context = CIContext()
    @MainActor var convertedImage: UIImage?
    @MainActor private var isLoading: Bool = false
    private let actor = CameraFeedActor()
    
//    @MainActor var convertedImage: UIImage?
    
    @MainActor
    override init() {
        super.init()
        
        self.actor.imageConverterDelegate = self
    }
    
    // updated signature per this comment: https://medium.com/@b99705008/great-tutorial-it-really-help-me-to-understand-the-process-to-implement-a-camera-capture-feature-4baeadfe0d96
    @MainActor
    func captureOutput(_ captureOutput: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard !self.isLoading else { return }
        self.isLoading = true
        
        Task(priority: .high) { [weak self] in
            await self?.actor.createUIImage(from: sampleBuffer)
        }
    }
}

protocol ImageConverterDelegate: AnyObject {
    @MainActor
    func imageConverted(image: UIImage)
}

extension CaptureSessionBufferDelegate: ImageConverterDelegate {
    func imageConverted(image: UIImage) {
        image.accessibilityIdentifier = CAMERA_DESCRIPTION
        
        self.convertedImage = image
        self.isLoading = false
        
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

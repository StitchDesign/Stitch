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
    var currentImage: UIImage?
    var bufferDelegate = CaptureSessionBufferDelegate()

    init(actor: CameraFeedActor) {
        super.init()

        self.actor = actor
        self.bufferDelegate.sessionDelegate = self

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
        //            self.commitConfiguration() // ORIGINAL

        guard let connection: AVCaptureConnection = videoOutput.connection(with: CAMERA_FEED_MEDIA_TYPE),
              connection.isVideoOrientationSupported,
              connection.isVideoMirroringSupported else {
            log("FrameExtractor: configureSession: Cannot establish connection")
            self.commitConfiguration() // commit configuration if we must exit
            return
        }

        // `StitchAVCaptureSession` is only used for devices / camera directions that DO NOT support Augmented Reality
        // e.g. Mac device, or iPad with front camera direction
        if let videoOrientation = self.getCameraOrientation(
            device: device,
            cameraOrientation: cameraOrientation) {
            connection.videoOrientation = videoOrientation
        }

        connection.isVideoMirrored = position == .front

        // Commit configuration only at the very end?
        self.commitConfiguration()

        // NOT NEEDED?
        //            let settings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA) ]
        //            videoOutput.videoSettings = settings
        //            videoOutput.alwaysDiscardsLateVideoFrames = true
        //        })
    }

    // iPad front camera needs landscapeRight setting (which also applies to rear camera.
    // Normal webcams on Mac don't need orientation set.
    private func getCameraOrientation(device: StitchCameraDevice,
                                      cameraOrientation: StitchCameraOrientation) -> AVCaptureVideoOrientation? {
        // Previously on Catalyst we always returned `nil`, i.e. never specificed camera orientation
        return cameraOrientation
            .convertOrientation
            .toAVCaptureVideoOrientation

        // TODO: WIP:
        //                #if targetEnvironment(macCatalyst)
        //                return nil
        //                #else
        //        return cameraOrientation.toAVCaptureVideoOrientation
        //        //
        //        //        // If not on Mac, use the specified camera orientation:
        //        //        if let cameraOrientation = cameraOrientation {
        //        //            return cameraOrientation
        //        //        }
        //        //        // Orientation changes needed on iPhone built-in camera
        //        //        else if isPhoneDevice() && device.isBuiltInCamera {
        //        //            return .portrait
        //        //        }
        //        //        // iPad defaults to .portrait
        //        //        else {
        //        //            //        return .landscapeRight
        //        //                    return .portrait
        //        //        }
        //        #endif
    }
}

/// Delegate class for managing image buffer from `AVCaptureSession`.
final class CaptureSessionBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    private let context = CIContext()
    private var processedImage: UIImage?
    private var isLoading: Bool = false
    
    weak var sessionDelegate: StitchCameraSession?
    
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
        
        DispatchQueue.main.async { [weak sessionDelegate, weak self] in
            guard let newImage = self?.processedImage else {
                return
            }
            
            sessionDelegate?.currentImage = newImage
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

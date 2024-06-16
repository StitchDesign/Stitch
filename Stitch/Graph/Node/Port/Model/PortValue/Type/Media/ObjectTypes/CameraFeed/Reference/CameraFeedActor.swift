//
//  CameraFeedActor.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 3/1/24.
//

import AVFoundation
import Foundation
import SwiftUI
import StitchSchemaKit

actor CameraFeedActor {
    var authStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: CAMERA_FEED_MEDIA_TYPE)
    }

    func configureSession(session: StitchCameraSession,
                          device: StitchCameraDevice,
                          position: AVCaptureDevice.Position,
                          cameraOrientation: StitchCameraOrientation) {
        guard authStatus == .authorized else {
            return
        }

        // Must call on main thread or AR may crash
        session.configureSession(
            device: device,
            position: position,
            cameraOrientation: cameraOrientation)

        session.startRunning()
    }

    func startCamera(session: StitchCameraSession,
                     device: StitchCameraDevice,
                     position: AVCaptureDevice.Position,
                     cameraOrientation: StitchCameraOrientation) {
        let authStatus = self.authStatus
        switch authStatus {
        case .authorized:
            self.configureSession(
                session: session,
                device: device,
                position: position,
                cameraOrientation: cameraOrientation)

        case .notDetermined:
            self.requestPermission(session: session,
                                   device: device,
                                   position: position,
                                   cameraOrientation: cameraOrientation)
        default:
            DispatchQueue.main.async {
                dispatch(CameraPermissionDeclined())
            }
        }
    }

    private func requestPermission(session: StitchCameraSession,
                                   device: StitchCameraDevice,
                                   position: AVCaptureDevice.Position,
                                   cameraOrientation: StitchCameraOrientation) {
        AVCaptureDevice.requestAccess(for: CAMERA_FEED_MEDIA_TYPE) { isGranted in
            Task { [weak self, weak session] in
                if let _session = session,
                   isGranted {
                    await self?.startCamera(
                        session: _session,
                        device: device,
                        position: position,
                        cameraOrientation: cameraOrientation)
                }
            }
        }
    }

    nonisolated static func createUIImage(from ciImage: CIImage,
                                          context: CIContext) -> UIImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let uiImage = UIImage(cgImage: cgImage)
        uiImage.accessibilityIdentifier = CAMERA_DESCRIPTION

        return  uiImage
    }
}

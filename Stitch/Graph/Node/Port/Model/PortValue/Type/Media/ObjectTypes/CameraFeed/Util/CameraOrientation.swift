//
//  CameraSettings.swift
//  prototype
//
//  Created by Elliot Boschwitz on 12/5/21.
//

import SwiftUI
import AVFoundation
import StitchSchemaKit

extension StitchCameraOrientation: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.cameraOrientation
    }

    /*
     AVCaptureVideoOrientationPortrait           = 1,
     AVCaptureVideoOrientationPortraitUpsideDown = 2,
     AVCaptureVideoOrientationLandscapeRight     = 3,
     AVCaptureVideoOrientationLandscapeLeft      = 4,
     */
    var toAVCaptureVideoOrientation: AVCaptureVideoOrientation {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        }
    }

    var toStitchDeviceOrientation: StitchDeviceOrientation {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        }
    }

    // Catalyst seems incorrect (e.g. .portrait is wider than it is tall),
    // therefore we convert Catalyst orientation to iPad orientation.
    var convertOrientation: Self {
        #if targetEnvironment(macCatalyst)
        switch self {
        case .portrait:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .landscapeRight
        case .landscapeLeft:
            return .portraitUpsideDown
        case .landscapeRight:
            return .portrait
        }
        #else
        // if we're already on iPad, nothing to convert
        return self
        #endif
    }

    static var defaultOrientation: Self {
        #if targetEnvironment(macCatalyst)
        return .portrait  // Will be converted to landscapeLeft by convertOrientation
        #else
        return .landscapeRight  // Default for iPad
        #endif
    }
}

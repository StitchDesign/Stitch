//
//  CameraUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/18/22.
//

import ARKit
import AVFoundation
import Foundation
import StitchSchemaKit

let CAMERA_PREF_KEY_NAME = "CameraPref"
let BUILT_IN_CAM_LABEL = "Built-In Camera"

let BUILT_IN_CAM_OPTION = AVCaptureDevicePickerOption(
    uniqueID: BUILT_IN_CAM_LABEL,
    // Try to find the default camera's actual name
    localizedName: AVCaptureDevice.getDefaultCamera()?.localizedName ?? "PSEUDO DEFAULT NAME")

extension AVCaptureDevice: @unchecked Sendable { }

/// Abstraction for types of cameras later used to determine with ARSession or AVCaptureSession should run,
/// since only one can run at a given time.
enum StitchCameraDevice: Sendable {
    case builtIn(AVCaptureDevice?)
    case custom(AVCaptureDevice?)

    var device: AVCaptureDevice? {
        switch self {
        case .builtIn(let aVCaptureDevice):
            return aVCaptureDevice
        case .custom(let aVCaptureDevice):
            return aVCaptureDevice
        }
    }

    var isBuiltInCamera: Bool {
        switch self {
        case .builtIn:
            return true
        case .custom:
            return false
        }
    }

    /// AR is supported if the AR configuration is available.
    var isARSupported: Bool {
        switch self {
        case .builtIn:
            return ARConfiguration.isSupported
        case .custom:
            return false
        }
    }
}

/// Obtains the user's last selected camera device (if any) on their particular device.
/// `UserDefaults` is used because this setting needs to be device-specific.
extension UserDefaults {
    func getCameraPref(position: AVCaptureDevice.Position) -> StitchCameraDevice {
        // We combine front + back cameras under one umbrella option.
        // If Catalyst, a "back" camera won't return an option so we request again for unspecified direction
        guard let cameraPrefId = self.object(forKey: CAMERA_PREF_KEY_NAME) as? String,
              cameraPrefId != BUILT_IN_CAM_LABEL else {
            return .builtIn(AVCaptureDevice.getDefaultCamera(specifiedPosition: position))
        }

        // First, look for cameras by specified position. If no results, try again, but set as .unspecified.
        // This is because most cameras don't have a front/back setting.
        let camerasByPosition = discoverExternalCameraDevices(position: position)
        //        guard camerasByPosition.isNotEmpty else {
        guard !camerasByPosition.isEmpty else {
            let camera = discoverExternalCameraDevices(position: .unspecified)
                .first { $0.uniqueID == cameraPrefId }
            return .custom(camera)
        }

        let result = camerasByPosition.first { $0.uniqueID == cameraPrefId }

        // If selected camera is iPad's dual camera, change the camera selection rather
        // than just its position
        if getDualCameraIDs().contains(where: { $0 == result?.uniqueID }) {
            let camera = AVCaptureDevice.getDefaultCamera(specifiedPosition: position)
            return .builtIn(camera)
        }

        return .custom(result)
    }

    /// Saves new camera choice to `UserDefaults`.
    func saveCameraPref(cameraID: String) -> StitchFileVoidResult {
        self.set(cameraID, forKey: CAMERA_PREF_KEY_NAME)
        return .success
    }
}

func discoverExternalCameraDevices(position: AVCaptureDevice.Position = .unspecified) -> [AVCaptureDevice] {
    // Can't call AVCaptureDevice from simulator
    #if targetEnvironment(simulator)
    []
    #else
    var allDevices = AVCaptureDevice
        .DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera],
                          mediaType: CAMERA_FEED_MEDIA_TYPE,
                          position: position)
        .devices

    let internalDevices = [AVCaptureDevice.getDefaultCamera(specifiedPosition: .front), AVCaptureDevice.getDefaultCamera(specifiedPosition: .back)]
    allDevices.removeAll { device in
        internalDevices.map { $0?.uniqueID }.contains(device.uniqueID)
    }

    return allDevices
    #endif
}

func getCameraPickerOptions() -> [AVCaptureDevicePickerOption] {
    let discoveredOptions = discoverExternalCameraDevices().map { $0.pickerOption }
    return [BUILT_IN_CAM_OPTION] + discoveredOptions
}

func getDualCameraIDs() -> [String] {
    let directions: [AVCaptureDevice.Position] = [.front, .back]
    return directions.compactMap { AVCaptureDevice.getDefaultCamera(specifiedPosition: $0)?.uniqueID }
}

/// Provides a minimal, Picker-supported data structure with the info necessary to populate
/// and identify an `AVCaptureDevice`.
struct AVCaptureDevicePickerOption: Hashable {
    let uniqueID: String
    let localizedName: String
}

extension AVCaptureDevice {
    var pickerOption: AVCaptureDevicePickerOption {
        AVCaptureDevicePickerOption(uniqueID: self.uniqueID,
                                    localizedName: self.localizedName)
    }

    static func getDefaultCamera(specifiedPosition: AVCaptureDevice.Position = .front) -> AVCaptureDevice? {
        // Can't call AVCaptureDevice from simulator
        #if targetEnvironment(simulator)
        nil
        #else
        Self.default(.builtInWideAngleCamera, // works for both front and back cameras
                     for: CAMERA_FEED_MEDIA_TYPE,
                     position: specifiedPosition)
            // If the above returns nil, try again with "unspecified" direction
            ?? Self.default(.builtInWideAngleCamera,
                            for: CAMERA_FEED_MEDIA_TYPE,
                            position: .unspecified)
        #endif
    }
}

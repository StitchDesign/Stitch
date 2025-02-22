//
//  DeviceInfoNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/25/22.
//

import Foundation
import StitchSchemaKit
import CoreMotion
import SwiftUI

let defaultColorScheme: ColorScheme = .dark

let LIGHT_COLOR_SCHEME = "Light"
let DARK_COLOR_SCHEME = "Dark"

extension ColorScheme {
    var description: String {
        switch self {
        case .light:
            return LIGHT_COLOR_SCHEME
        case .dark:
            return DARK_COLOR_SCHEME
        @unknown default:
            return "Unknown Color Scheme"
        }
    }
}

extension DeviceAppearance: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.deviceAppearance
    }

    static let defaultDeviceAppearance: Self = .system
}

extension MaterialThickness: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.materialThickness
    }

    static let defaultMaterialThickness: Self = .regular
}

extension StitchDeviceOrientation: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.deviceOrientation
    }

    static let defaultDeviceOrientation: Self = .portrait

    var toStitchCameraOrientation: StitchCameraOrientation {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .unknown, .faceUp, .faceDown:
            log("toStitchCameraOrientation: defaulting to portrait for device orientation \(self)")
            return .portrait
        }
    }
}

extension UIDeviceOrientation {

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
        case .unknown:
            return .unknown
        case .faceUp:
            return .faceUp
        case .faceDown:
            return .faceDown
        @unknown default:
            log("UIDeviceOrientation.toStitchDeviceOrientation: unknown default")
            return .unknown
        }
    }

    var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .portrait:
            return "Portrait"
        case .portraitUpsideDown:
            return "Portrait upside down"
        case .landscapeLeft:
            return "Landscape left"
        case .landscapeRight:
            return "Landscape right"
        case .faceUp:
            return "Face up"
        case .faceDown:
            return "Face down"
        @unknown default:
            return "Unknown Default"
        }
    }
}

@MainActor
func deviceInfoNode(id: NodeId,
                    position: CGSize = .zero,
                    zIndex: Double = 0) -> PatchNode {

    let inputs = fakeInputs(id: id)

    // has outputs only; outputs updated by eval drawing on state
    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            ("Screen Size", [.size(DEFAULT_LANDSCAPE_SIZE.toLayerSize)]), // 0

        // graph zoom
        ("Screen Scale", [.number(1)]), // 1

        // 0, 90, 180 or 270 degrees
        // will use UIDevice.orientation
        ("Orientation", [.deviceOrientation(.defaultDeviceOrientation)]), // 2

        ("Device Type", [.string(.init("iPad"))]), // 3

        ("Appearance", [.string(.init(defaultColorScheme.description))]), // 4
        ("Safe Area Top", [.number(0)]), // 5

        ("Safe Area Bottom", [.number(0)]) // 6
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .deviceInfo,
        inputs: inputs,
        outputs: outputs)
}

// just pulls from the state; has no inputs and can never be a loop

// Returns PatchNode, ie we're only updating the patch node, not the state;
// we're just READING FROM the state
@MainActor
func deviceInfoEval(node: PatchNode,
                    state: GraphDelegate) -> EvalResult {

    //    log("deviceInfoEval called")

    let deviceSize = UIScreen.main.bounds.size

    let orientation: UIDeviceOrientation = UIDevice.current.orientation

    // TODO: rewrite the SO code to get around this linter warning?
    let deviceType = UIDevice().type // UIDevice.current.model

    //    #if DEV_DEBUG
    //    log("deviceInfoEval: deviceSize: \(deviceSize)")
    //
    //    log("deviceInfoEval: orientation: \(orientation)")
    //    log("deviceInfoEval: orientation.isFlat: \(orientation.isFlat)")
    //    log("deviceInfoEval: orientation.isPortrait: \(orientation.isPortrait)")
    //    log("deviceInfoEval: orientation.isLandscape: \(orientation.isLandscape)")
    //    log("deviceInfoEval: orientation.isValidInterfaceOrientation: \(orientation.isValidInterfaceOrientation)")
    //
    //    log("deviceInfoEval: deviceType.rawValue: \(deviceType.rawValue)")
    //    #endif

    let outputs: PortValuesList = [
        [.size(deviceSize.toLayerSize)],
        [.number(state.graphMovement.zoomData.zoom)],
        [.deviceOrientation(orientation.toStitchDeviceOrientation)],
        [.string(.init(deviceType.rawValue))],
        [.string(.init(defaultColorScheme.description))],
        [
            .number(state.safeAreaInsets.top)
        ],
        [
            .number(state.safeAreaInsets.bottom)
        ]
    ]

    return .init(outputsValues: outputs)
}

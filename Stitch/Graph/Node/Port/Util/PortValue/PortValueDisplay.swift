//
//  PortValueDisplay.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/3/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON
import OrderedCollections

let WIDTH = "width"
let HEIGHT = "height"
let X = "x"
let Y = "y"
let Z = "z"
let W = "w"

let TOP = "Top"
let RIGHT = "Right"
let BOTTOM = "Bottom"
let LEFT = "Left"



extension LayerSize {
    var asLayerDictionary: [String: String] {
        [
            WIDTH: self.width.description,
            HEIGHT: self.height.description
        ]
    }
}

extension CGSize {
    var asDictionary: [String: Double] {
        [
            WIDTH: self.width,
            HEIGHT: self.height
        ]
    }
}

extension Point3D {
    var asDictionary: [String: Double] {
        [
            X: self.x,
            Y: self.y,
            Z: self.z
        ]
    }
}

extension Point4D {
    var asDictionary: [String: Double] {
        [
            X: self.x,
            Y: self.y,
            Z: self.z,
            W: self.w
        ]
    }
}

extension StitchPadding {
    var asDictionary: [String: Double] {
        [
            TOP: self.top,
            RIGHT: self.right,
            BOTTOM: self.bottom,
            LEFT: self.left
        ]
    }
}

// TODO: do you need to handle .shapeCommand here?
// ShapeCommand is a more complicated format
extension PortValue {

    // a JSON friendly format
    @MainActor
    func createJSONFormat() -> JSONFriendlyFormat {
        .init(value: self)
    }

    // This is the 'raw string' that we display to the user
    var display: String {
        switch self {
        case let .string(x):
            return x.string
        case let .number(x):
            return GlobalFormatter.string(for: x) ?? x.description
        case let .layerDimension(x):
            return x.description
        case let .int(x):
            return x.description
        case let .bool(x):
            return x.description
        case let .color(x):
            return x.asHexDisplay
        case let .size(x):
            return x.asAlgebraicCGSize.asDictionary.description
        case let .position(x):
            return x.asDictionary.description
        case let .point3D(x):
            return x.asDictionary.description
        case let .point4D(x):
            return x.asDictionary.description
        case .matrixTransform:
            return "AR Transform"
        case .plane(let plane):
            return plane.display
        case .pulse(let time):
            return time.rounded(toPlaces: 4).description
        case .none:
            return "none"
        case .asyncMedia(let media):
            return (media?.mediaKey?.filename ?? nil) ?? "None"
        case .json(let x):
            return x.display
        case .networkRequestType(let x):
            return x.display
        case .anchoring(let x):
            return x.display
        case  .cameraDirection(let x):
            return x.display
        case .assignedLayer(let x):
            return x?.id.description ?? "No Layers" // Doesn't seem correct?
        case .pinTo(let x):
            return x.display
        case .scrollMode(let x):
            return x.display
        case .textAlignment(let x):
            return x.display
        case .textVerticalAlignment(let x):
            return x.display
        case let .textDecoration(x):
            return x.display
        case let .textFont(x):
            return x.display
        case .fitStyle(let x):
            return x.display
        case .animationCurve(let x):
            return x.displayName
        case .lightType(let x):
            return x.display
        case .layerStroke(let x):
            return x.display
        case .textTransform(let x):
            return x.display
        case .dateAndTimeFormat(let x):
            return x.display
        case .shape:
            return "Shape"
        case .scrollJumpStyle(let x):
            return x.display
        case .scrollDecelerationRate(let x):
            return x.display
        case .comparable(let x):
            return x?.display ?? "No Value"
        case .delayStyle(let x):
            return x.rawValue
        case .shapeCoordinates(let x):
            return x.rawValue
        case .orientation(let x):
            return x.display
        case .cameraOrientation(let x):
            return x.rawValue
        case .shapeCommandType(let x):
            return x.display
        case .shapeCommand(let x):
            return x.getShapeCommandType.display
        case .deviceOrientation(let x):
            return x.rawValue
        case .vnImageCropOption(let x):
            return x.label
        case .blendMode(let x):
            return x.rawValue
        case .mapType(let x):
            return x.rawValue
        case .progressIndicatorStyle(let x):
            return x.rawValue
        case .mobileHapticStyle(let x):
            return x.rawValue
        case .strokeLineCap(let x):
            return x.rawValue
        case .strokeLineJoin(let x):
            return x.rawValue
        case .contentMode(let x):
            return x.rawValue
        case .spacing(let x):
            return x.display
        case .padding(let x):
            return x.asDictionary.description
        case .sizingScenario(let x):
            return x.rawValue

        /*
         See https://github.com/vpl-codesign/stitch/issues/3022

         "What happens when we plug a ShapeCommand into a Text layer node's String input?"

         If we display a ShapeCommand as a JSON in (instead of just its ShapeCommandType),
         the JSON changes e.g. as we change colors in a Text layer,
         since the ShapeCommand is re-encoded on every preview window re-render.

         Options:
         - only show the ShapeCommandType, like we currently do?
         - sort the JSON? (Expensive perf-wise?)
         - cache the JSON representation of the ShapeCommand?
         */

        // return x.display
        }
    }
}

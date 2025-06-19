//
//  UserVisibleType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/* ----------------------------------------------------------------
 User-visible types: what the user sees
 ---------------------------------------------------------------- */

public typealias NodeType = UserVisibleType

extension UserVisibleType {
    // TODO: handle special case with .string as "String" vs "Text"
    var displayForNodeMenu: String {
        if self == .string {
            return "Text"
        } else {
            return self.display
        }
    }
}

extension UserVisibleType {
    init(_ value: PortValue) {
        self = portValueToNodeType(value)
    }
}

extension PortValue {
    var toNodeType: UserVisibleType {
        portValueToNodeType(self)
    }
}

// Only used in `changeInputType`
func portValueToNodeType(_ value: PortValue) -> UserVisibleType {
    switch value {
    case .string:
        return .string
    case .bool:
        return .bool
    case .color:
        return .color
    case .number:
        return .number
    case .layerDimension:
        return .layerDimension
    case .size:
        return .size
    case .position:
        return .position
    case .point3D:
        return .point3D
    case .point4D:
        return .point4D
    case .transform:
        return .transform
    case .plane:
        return .plane
    case .pulse:
        return .pulse
    case .asyncMedia:
        return .media
    case .json:
        return .json
    case .networkRequestType:
        return .networkRequestType
    case .none:
        return .none
    case .anchoring:
        return .anchoring
    case .cameraDirection:
        return .cameraDirection
    case .assignedLayer:
        return .interactionId
    case .scrollMode:
        return .scrollMode
    case .textAlignment:
        return .textAlignment
    case .textVerticalAlignment:
        return .textVerticalAlignment
    case .fitStyle:
        return .fitStyle
    case .animationCurve:
        return .animationCurve
    case .lightType:
        return .lightType
    case .layerStroke:
        return .layerStroke
    case .textTransform:
        return .textTransform
    case .dateAndTimeFormat:
        return .dateAndTimeFormat
    case .shape:
        return .shape
    case .scrollJumpStyle:
        return .scrollJumpStyle
    case .scrollDecelerationRate:
        return .scrollDecelerationRate
    case .comparable(let type):
        switch type {
        case .none:
            return .none
        case .number:
            return .number
        case .string:
            return .string
        case .bool:
            return .bool
        }
    case .delayStyle:
        return .delayStyle
    case .shapeCoordinates:
        return .shapeCoordinates
    case .shapeCommand:
        return .shapeCommand
    case .shapeCommandType:
        return .shapeCommandType
    case .orientation:
        return .orientation
    case .cameraOrientation:
        return .cameraOrientation
    case .deviceOrientation:
        return .deviceOrientation
    case .vnImageCropOption:
        return .vnImageCropOption
    case .textDecoration:
        return .textDecoration
    case .textFont:
        return .textFont
    case .blendMode:
        return .blendMode
    case .mapType:
        return .mapType
    case .progressIndicatorStyle:
        return .progressIndicatorStyle
    case .mobileHapticStyle:
        return .mobileHapticStyle
    case .strokeLineCap:
        return .strokeLineCap
    case .strokeLineJoin:
        return .strokeLineJoin
    case .contentMode:
        return .contentMode
    case .spacing:
        return .spacing
    case .padding:
        return .padding
    case .sizingScenario:
        return .sizingScenario
    case .pinTo:
        return .pinToId
    case .materialThickness:
        return .materialThickness
    case .deviceAppearance:
        return .deviceAppearance
    case .anchorEntity:
        return .anchorEntity
    case .keyboardType:
        return .keyboardType
    case .buttonStyle:
        return .buttonStyle
    case .buttonRole:
        return .buttonRole
    case .buttonBorderShape:
        return .buttonBorderShape
    case .buttonRepeatBehavior:
        return .buttonRepeatBehavior
    }
}

extension StitchAINodeType {
    /// Migrates Stitch AI's node type to runtime.
    func migrate() throws -> NodeType {
        try NodeTypeVersion.migrate(entity: self,
                                    version: CurrentStep.documentVersion)
    }
}


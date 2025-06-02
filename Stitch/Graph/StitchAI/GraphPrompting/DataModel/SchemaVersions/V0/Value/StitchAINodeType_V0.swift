//
//  StitchAINodeType_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

extension StitchAIPortValue_V0.NodeType {
    var defaultPortValue: StitchAIPortValue_V0.PortValue {
        //    log("nodeTypeToPortValue: nodeType: \(nodeType)")
        switch self {
        case .string:
            return .string(.init(""))
        case .number, .int:
            return .number(.zero)
        case .layerDimension:
            return .number(.zero)
        case .bool:
            return .bool(false)
        case .color:
            return .color(falseColor)
        // NOT CORRECT FOR size, position, point3D etc.
        // because eg position becomes
        case .size:
            return .size(.init(width: 0, height: 0))
        case .position:
            return .position(.init(x: 0, y: 0))
        case .point3D:
            return .point3D(.init(x: 0, y: 0, z: 0))
        case .point4D:
            return .point4D(.init(x: 0, y: 0, z: 0, w: 0))
        case .transform:
            return .transform(.init())
        case .pulse:
            return .pulse(.zero)
        case .media:
            return .asyncMedia(nil)
        case .json:
            return .json(.init(.init(parseJSON: jsonDefaultRaw)))
        case .none:
            return .none
        case .anchoring:
            return .anchoring(.init(x: 0, y: 0))
        case .cameraDirection:
            return .cameraDirection(.front)
        case .interactionId:
            return .assignedLayer(nil)
        case .scrollMode:
            return .scrollMode(.free)
        case .textAlignment:
            return .textAlignment(.left)
        case .textVerticalAlignment:
            return .textVerticalAlignment(.top)
        case .fitStyle:
            return .fitStyle(.fill)
        case .animationCurve:
            return .animationCurve(.linear)
        case .lightType:
            return .lightType(.ambient)
        case .layerStroke:
            return .layerStroke(.none)
        case .textTransform:
            return .textTransform(.uppercase)
        case .dateAndTimeFormat:
            return .dateAndTimeFormat(.medium)
        case .shape:
            return .shape(.init(.triangle(
                .init(p1: TriangleData.defaultTriangleP1,
                      p2: TriangleData.defaultTriangleP2,
                      p3: TriangleData.defaultTriangleP3))))
        case .scrollJumpStyle:
            return .scrollJumpStyle(.instant)
        case .scrollDecelerationRate:
            return .scrollDecelerationRate(.normal)
        case .plane:
            return .plane(.any)
        case .networkRequestType:
            return .networkRequestType(.get)
        case .delayStyle:
            return .delayStyle(.always)
        case .shapeCoordinates:
            return .shapeCoordinates(.relative)
        case .shapeCommand:
            return .shapeCommand(.moveTo(point: .init(x: 0, y: 0)))
        case .shapeCommandType:
            return .shapeCommandType(.moveTo)
        case .orientation:
            return .orientation(.none)
        case .cameraOrientation:
#if targetEnvironment(macCatalyst)
            return .cameraOrientation(.portrait)  // Will be converted to landscapeLeft by convertOrientation
#else
            return .cameraOrientation(.landscapeRight)  // Default for iPad
#endif
        case .deviceOrientation:
            return .deviceOrientation(.portrait)
        case .vnImageCropOption:
            return .vnImageCropOption(.centerCrop)
        case .textDecoration:
            return .textDecoration(.none)
        case .textFont:
            return .textFont(.init(fontChoice: .sf,
                                   fontWeight: .SF_regular))
        case .blendMode:
            return .blendMode(.normal)
        case .mapType:
            return .mapType(.standard)
        case .mobileHapticStyle:
            return .mobileHapticStyle(.heavy)
        case .progressIndicatorStyle:
            return .progressIndicatorStyle(.circular)
        case .strokeLineCap:
            return .strokeLineCap(.round)
        case .strokeLineJoin:
            return .strokeLineJoin(.round)
        case .contentMode:
            return .contentMode(.fit)
        case .spacing:
            return .spacing(.number(.zero))
        case .padding:
            return .padding(.init(top: .zero,
                                  right: .zero,
                                  bottom: .zero,
                                  left: .zero))
        case .sizingScenario:
            return .sizingScenario(.auto)
        case .pinToId:
            return .pinTo(PinToId_V31.PinToId.root)
        case .deviceAppearance:
            return .deviceAppearance(.system)
        case .materialThickness:
            return .materialThickness(.regular)
        case .anchorEntity:
            return .anchorEntity(nil)
        }
    }
}

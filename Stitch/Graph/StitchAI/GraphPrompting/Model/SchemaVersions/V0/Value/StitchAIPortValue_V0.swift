//
//  StitchAIPortValue.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAIPortValue_V0: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V0
    typealias PortValueVersion = PortValue_V31
    typealias PortValue = PortValueVersion.PortValue
    typealias NodeType = UserVisibleType_V31.UserVisibleType
    typealias LayerSize = LayerSize_V31.LayerSize
    typealias TextDecoration = LayerTextDecoration_V31.LayerTextDecoration
    typealias CustomShape = CustomShape_V31.CustomShape
    typealias PreviousInstance = Self.StitchAIPortValue
    // MARK: - end
    
    struct StitchAIPortValue {
        let value: PortValue
        
        init(_ value: PortValue) {
            self.value = value
        }
        
        enum CodingKeys: String, CodingKey {
            case value
            case type = "value_type"
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // extract type
            let nodeTypeString = try container.decode(String.self, forKey: .type)
            guard let nodeType = NodeType(llmString: nodeTypeString) else {
                throw StitchAIManagerError.nodeTypeNotSupported(nodeTypeString)
            }
            
            // portvalue
            let portValueType = nodeType.portValueTypeForStitchAI
            let decodedValue = try container.decode(portValueType, forKey: .value)
            let value = try nodeType.coerceToPortValueForStitchAI(from: decodedValue)
            self.value = value
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(value.nodeType.asLLMStepNodeType, forKey: .type)
            try container.encode(value.anyCodable, forKey: .value)
        }
    }
}

extension StitchAIPortValue_V0.StitchAIPortValue: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAIPortValue_V0.StitchAIPortValue) {
        fatalError()
    }
}

extension StitchAIPortValue_V0.PortValue {
    init?(decoderContainer: KeyedDecodingContainer<Step_V0.Step.CodingKeys>,
          type: StitchAIPortValue_V0.NodeType) throws {
        let portValueType = type.portValueTypeForStitchAI
        
        guard let decodedValue = try decoderContainer
            .decodeIfPresentSitchAI(portValueType, forKey: .value) else {
            // No value
            return nil
        }
        
        let value = try type.coerceToPortValueForStitchAI(from: decodedValue)
        self = value
    }
    
    var anyCodable: any Codable {
        switch self {
        case .string(let x):
            return x.string
        case .bool(let x):
            return x
        case .number(let x):
            return x
        case .layerDimension(let x):
            return StitchAISizeDimension(value: x)
        case .transform(let x):
            return x
        case .plane(let x):
            return x
        case .networkRequestType(let x):
            return x
        case .color(let x):
            return StitchAIColor(value: x)
        case .size(let size):
            return StitchAISize(width: .init(value: size.width),
                                height: .init(value: size.height))
        case .position(let x):
            return StitchAIPosition(x: x.x, y: x.y)
        case .point3D(let x):
            return x
        case .point4D(let x):
            return x
        case .pulse(let x):
            return x
        case .asyncMedia(let x):
            return x
        case .json(let x):
            return x
        case .anchoring(let x):
            return x
        case .cameraDirection(let x):
            return x
        case .assignedLayer(let x):
            guard let x = x else {
                return nil as StitchAIUUID?
            }
            return StitchAIUUID(value: x.id)
        case .scrollMode(let x):
            return x
        case .textAlignment(let x):
            return x
        case .textVerticalAlignment(let x):
            return x
        case .fitStyle(let x):
            return x
        case .animationCurve(let x):
            return x
        case .lightType(let x):
            return x
        case .layerStroke(let x):
            return x
        case .textTransform(let x):
            return x
        case .dateAndTimeFormat(let x):
            return x
        case .shape(let x):
            return x
        case .scrollJumpStyle(let x):
            return x
        case .scrollDecelerationRate(let x):
            return x
        case .comparable(let x):
            return x
        case .delayStyle(let x):
            return x
        case .shapeCoordinates(let x):
            return x
        case .shapeCommandType(let x):
            return x
        case .shapeCommand(let x):
            return x
        case .orientation(let x):
            return x
        case .cameraOrientation(let x):
            return x
        case .deviceOrientation(let x):
            return x
        case .vnImageCropOption(let x):
            return x
        case .textDecoration(let x):
            return x
        case .textFont(let x):
            return x
        case .blendMode(let x):
            return x
        case .mapType(let x):
            return x
        case .progressIndicatorStyle(let x):
            return x
        case .mobileHapticStyle(let x):
            return x
        case .strokeLineCap(let x):
            return x
        case .strokeLineJoin(let x):
            return x
        case .contentMode(let x):
            return x
        case .spacing(let x):
            return x
        case .padding(let x):
            return x
        case .sizingScenario(let x):
            return x
        case .pinTo(let x):
            return x
        case .deviceAppearance(let x):
            return x
        case .materialThickness(let x):
            return x
        case .anchorEntity(let x):
            guard let x = x else {
                return nil as StitchAIUUID?
            }
            return StitchAIUUID(value: x)
        case .none, .int:
            fatalError()
        }
    }
    
    var nodeType: StitchAIPortValue_V0.NodeType {
        switch self {
        case .int:
            fatalErrorIfDebug()
            return .int
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
        }
    }
}

//
//  StitchAIPortValue.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAIPortValue_V1: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V1
    typealias PortValueVersion = PortValue_V32
    typealias PortValue = PortValueVersion.PortValue
    typealias NodeType = UserVisibleType_V32.UserVisibleType
    typealias LayerSize = LayerSize_V32.LayerSize
    typealias TextDecoration = LayerTextDecoration_V32.LayerTextDecoration
    typealias CustomShape = CustomShape_V32.CustomShape
    typealias SizeDimension = StitchAISizeDimension_V1.StitchAISizeDimension
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

extension StitchAIPortValue_V1.StitchAIPortValue: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAIPortValue_V1.StitchAIPortValue) {
        fatalError()
    }
}

extension StitchAIPortValue_V1.PortValue {
    init?(decoderContainer: KeyedDecodingContainer<Step_V1.Step.CodingKeys>,
          type: StitchAIPortValue_V1.NodeType) throws {
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
            return StitchAIPortValue_V1.SizeDimension(value: x)
        case .transform(let x):
            return x
        case .plane(let x):
            return x
        case .networkRequestType(let x):
            return x
        case .color(let x):
            return StitchAIColor_V1.StitchAIColor(value: x)
        case .size(let size):
            return StitchAISize_V1
                .StitchAISize(width: .init(value: size.width),
                              height: .init(value: size.height))
        case .position(let x):
            return StitchAIPosition_V1.StitchAIPosition(x: x.x, y: x.y)
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
                return nil as StitchAIUUID_V1.StitchAIUUID?
            }
            return StitchAIUUID_V1.StitchAIUUID(value: x.id)
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
            if let customShape = x {
                return customShape.toHumanReadable()
            }
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
                return nil as StitchAIUUID_V1.StitchAIUUID?
            }
            return StitchAIUUID_V1.StitchAIUUID(value: x)
        case .keyboardType(let x):
            return x
        case .none:
            fatalError()
        }
    }
    
    var nodeType: StitchAIPortValue_V1.NodeType {
        switch self {
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
        }
    }
}

public struct HumanReadableCustomShape_V1: Codable {
    public struct HumanReadableTriangle: Codable {
        public let p1: [CGFloat]
        public let p2: [CGFloat]
        public let p3: [CGFloat]
    }

    public struct HumanReadableRectangle: Codable {
        public let cornerRadius: CGFloat
        public let rect: [[CGFloat]]
    }

    public struct HumanReadableCircle: Codable {
        public let rect: [[CGFloat]]
    }

    public enum Shape: Codable {
        case triangle(HumanReadableTriangle)
        case rectangle(HumanReadableRectangle)
        case circle(HumanReadableCircle)
        case oval(HumanReadableCircle)
        case custom([ShapeCommand_V32.ShapeCommand])

        enum CodingKeys: String, CodingKey {
            case type, data
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .triangle(let triangle):
                try container.encode("triangle", forKey: .type)
                try container.encode(triangle, forKey: .data)
            case .rectangle(let rectangle):
                try container.encode("rectangle", forKey: .type)
                try container.encode(rectangle, forKey: .data)
            case .circle(let circle):
                try container.encode("circle", forKey: .type)
                try container.encode(circle, forKey: .data)
            case .oval(let oval):
                try container.encode("oval", forKey: .type)
                try container.encode(oval, forKey: .data)
            case .custom(let commands):
                try container.encode("custom", forKey: .type)
                try container.encode(commands, forKey: .data)
            }
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "triangle":
                let data = try container.decode(HumanReadableTriangle.self, forKey: .data)
                self = .triangle(data)
            case "rectangle":
                let data = try container.decode(HumanReadableRectangle.self, forKey: .data)
                self = .rectangle(data)
            case "circle":
                let data = try container.decode(HumanReadableCircle.self, forKey: .data)
                self = .circle(data)
            case "oval":
                let data = try container.decode(HumanReadableCircle.self, forKey: .data)
                self = .oval(data)
            case "custom":
                let data = try container.decode([ShapeCommand_V32.ShapeCommand].self, forKey: .data)
                self = .custom(data)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown shape type: \(type)")
            }
        }
    }

    public let shapes: [Shape]
}

public extension CustomShape_V32.CustomShape {
    func toHumanReadable() -> HumanReadableCustomShape_V1 {
        let readableShapes: [HumanReadableCustomShape_V1.Shape] = shapes.map { shape in
            switch shape {
            case .triangle(let t):
                return .triangle(.init(
                    p1: [t.p1.x, t.p1.y],
                    p2: [t.p2.x, t.p2.y],
                    p3: [t.p3.x, t.p3.y]
                ))
            case .rectangle(let r):
                return .rectangle(.init(
                    cornerRadius: r.cornerRadius,
                    rect: [
                        [r.rect.origin.x, r.rect.origin.y],
                        [r.rect.maxX, r.rect.maxY]
                    ]
                ))
            case .circle(let rect):
                return .circle(.init(rect: [
                    [rect.origin.x, rect.origin.y],
                    [rect.maxX, rect.maxY]
                ]))
            case .oval(let rect):
                return .oval(.init(rect: [
                    [rect.origin.x, rect.origin.y],
                    [rect.maxX, rect.maxY]
                ]))
            case .custom(let cmds):
                let upgraded = cmds.map { ShapeCommand_V32.ShapeCommand(json: $0) }
                return .custom(upgraded)
            }
        }

        return HumanReadableCustomShape_V1(shapes: readableShapes)
    }
}

extension ShapeCommand_V32.ShapeCommand {
    init(json: JSONShapeCommand_V32.JSONShapeCommand) {
        switch json {
        case .closePath:
            self = .closePath
        case .moveTo(let pt):
            self = .moveTo(point: PathPoint_V32.PathPoint(x: pt.x, y: pt.y))
        case .lineTo(let pt):
            self = .lineTo(point: PathPoint_V32.PathPoint(x: pt.x, y: pt.y))
        case .curveTo(let c):
            self = .curveTo(
                curveFrom: PathPoint_V32.PathPoint(x: c.controlPoint1.x, y: c.controlPoint1.y),
                point: PathPoint_V32.PathPoint(x: c.point.x, y: c.point.y),
                curveTo: PathPoint_V32.PathPoint(x: c.controlPoint2.x, y: c.controlPoint2.y)
            )
        }
    }
}

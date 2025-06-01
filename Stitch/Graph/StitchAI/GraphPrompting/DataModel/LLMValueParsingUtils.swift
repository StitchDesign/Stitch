//
//  LLMValueParsingUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/29/25.
//

import Foundation
import SwiftUI
import SwiftyJSON
import StitchSchemaKit

extension String {
    // (String, NodeType) -> PortValue
    // i.e. handling the serialized
    func parseAsPortValue(_ nodeType: NodeType) -> PortValue? {
        log("String: parseAsPortValue: self: \(self)")
        log("String: parseAsPortValue: nodeType: \(nodeType)")
        
        let x = self
        
        switch nodeType {
        
        case .string:
            return .string(.init(x))
        
        case .bool:
            return parseUpdate(nodeType.defaultPortValue, x)
        
        case .number:
            return numberParser(x)
        
        // should be a layer size, i.e. a string?
        case .layerDimension:
            // TODO: JAN 29: is this correct?
            return parseUpdate(nodeType.defaultPortValue, x)
        
        case .transform:
            // TODO: JAN 29: use a full dictionary here?
            fatalErrorIfDebug()
            return nil
        
        case .plane:
            return Plane(rawValue: x).map(PortValue.plane)
        
        case .networkRequestType:
            return NetworkRequestType(rawValue: x).map(PortValue.networkRequestType)
        
        case .color:
            if let uiColorFromHex = UIColor(hex: self) {
                return .color(uiColorFromHex.toColor)
            }
            fatalErrorIfDebug()
            return nil
        
        case .size:
            return parseJSON(x)?.toSize.map(PortValue.size)
        
        case .position:
            return parseJSON(x)?.toStitchPosition.map(PortValue.position)
        
        case .point3D:
            return parseJSON(x)?.toPoint3D.map(PortValue.point3D)
        
        case .point4D:
            return parseJSON(x)?.toPoint4D.map(PortValue.point4D)
            
        case .pulse:
            // TODO: JAN 29: how does LLM handle pulses?
            return numberParser(x)
        
        case .media: // aka .asyncMedia
            // TODO: JAN 29: how does LLM handle media?
            fatalErrorIfDebug()
            return nil
        
        case .json:
            return parseJSON(x).map { PortValue.json(.init($0)) }
            
        case .none:
            // TODO: JAN 29: not really used?
            return PortValue.none
        
        case .anchoring:
            return parseJSON(x)?.toStitchPosition.map {
                .anchoring(Anchoring(x: $0.x, y: $0.y))
            }
            
        case .cameraDirection:
            return CameraDirection(rawValue: x).map(PortValue.cameraDirection)
        
        // treat as a string?
            // What happens if assigned layer = nil
        case .interactionId: // aka .assignedLayer
            // TODO: JAN 29: better way to handle nil with JSONFriendlyFormat
            // i.e. x?.id.description ?? "None"
            if let id = UUID(uuidString: x) {
                return .assignedLayer(.init(id))
            } else {
                return .assignedLayer(nil)
            }
            
        case .scrollMode:
            return ScrollMode(rawValue: x).map(PortValue.scrollMode)
        case .textAlignment:
            return LayerTextAlignment(rawValue: x).map(PortValue.textAlignment)
        case .textVerticalAlignment:
            return LayerTextVerticalAlignment(rawValue: x).map(PortValue.textVerticalAlignment)
        case .fitStyle:
            return VisualMediaFitStyle(rawValue: x).map(PortValue.fitStyle)
        case .animationCurve:
            return ClassicAnimationCurve(rawValue: x).map(PortValue.animationCurve)
        case .lightType:
            return LightType(rawValue: x).map(PortValue.lightType)
        case .layerStroke:
            return LayerStroke(rawValue: x).map(PortValue.layerStroke)
        case .textTransform:
            return TextTransform(rawValue: x).map(PortValue.textTransform)
        case .dateAndTimeFormat:
            return DateAndTimeFormat(rawValue: x).map(PortValue.dateAndTimeFormat)
        
        // treat as string ? or?
        case .shape:
            // TODO: JAN 29: PortValue.shape is not really handled properly?
            fatalErrorIfDebug()
            return nil
            
        case .scrollJumpStyle:
            return ScrollJumpStyle(rawValue: x).map(PortValue.scrollJumpStyle)
        case .scrollDecelerationRate:
            return ScrollDecelerationRate(rawValue: x).map(PortValue.scrollDecelerationRate)
                    
        case .delayStyle:
            return DelayStyle(rawValue: x).map(PortValue.delayStyle)
        case .shapeCoordinates:
            return ShapeCoordinates(rawValue: x).map(PortValue.shapeCoordinates)
        case .shapeCommandType:
            return ShapeCommandType(rawValue: x).map(PortValue.shapeCommandType)
        
        case .shapeCommand:
            fatalErrorIfDebug()
            return nil
            
        case .orientation:
            return StitchOrientation(rawValue: x).map(PortValue.orientation)
        case .cameraOrientation:
            return StitchCameraOrientation(rawValue: x).map(PortValue.cameraOrientation)
        case .deviceOrientation:
            return StitchDeviceOrientation(rawValue: x).map(PortValue.deviceOrientation)
        
        case .vnImageCropOption:
            fatalErrorIfDebug()
            return nil
            
        case .textDecoration:
            return LayerTextDecoration(rawValue: x).map(PortValue.textDecoration)
        
        case .textFont: // a struct
            fatalErrorIfDebug()
            return nil
            
        case .blendMode:
            return StitchBlendMode(rawValue: x).map { .blendMode($0) }

        case .mapType:
            return StitchMapType(rawValue: x).map(PortValue.mapType)

        case .progressIndicatorStyle:
            return ProgressIndicatorStyle(rawValue: x).map(PortValue.progressIndicatorStyle)

        case .mobileHapticStyle:
            return MobileHapticStyle(rawValue: x).map(PortValue.mobileHapticStyle)

        case .strokeLineCap:
            return StrokeLineCap(rawValue: x).map(PortValue.strokeLineCap)

        case .strokeLineJoin:
            return StrokeLineJoin(rawValue: x).map(PortValue.strokeLineJoin)

        case .contentMode:
            return StitchContentMode(rawValue: x).map(PortValue.contentMode)

        case .spacing:
            return spacingParser(self)
            
        case .padding:
            return parseJSON(x)?.toStitchPadding.map(PortValue.padding)
            
        case .sizingScenario:
            return SizingScenario(rawValue: x).map(PortValue.sizingScenario)
        
        case .pinToId:
            if let pinId = PinToId.fromString(self) {
                return .pinTo(pinId)
            } else {
                fatalErrorIfDebug()
                return nil
            }
            
        case .deviceAppearance:
            return DeviceAppearance(rawValue: x).map(PortValue.deviceAppearance)
            
        case .materialThickness:
            return MaterialThickness(rawValue: x).map(PortValue.materialThickness)
            
        case .anchorEntity:
            // TODO: JAN 29: handle properly
            fatalErrorIfDebug()
            return nil
        }
    }
}

extension JSONDecoder {
    func decodeStitchAI<T>(_ Type: T.Type,
                           data: Data) throws -> T? where T: Decodable {
        guard let decodedValue = try? self.decode(T.self, from: data) else {
            return try self.decodeIfString(Type, data: data)
        }
        
        return decodedValue
    }
    
    private func decodeIfString<T>(_ Type: T.Type,
                                   data: Data) throws -> T? where T: Decodable {
        guard let string = try? self.decode(String.self,
                                            from: data) else {
//            log("decodeIfString: could not parse string type.")
            return nil
        }
        
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        do {
            let result = try self.decode(T.self, from: data)
            return result
        } catch {
            throw StitchAIParsingError.decodeObjectFromString(string, error.localizedDescription)
        }
    }
}

extension KeyedDecodingContainerProtocol {
    func decodeIfPresentSitchAI<T>(_ Type: T.Type,
                                   forKey key: KeyedDecodingContainer<Key>.Key) throws -> T? where T: Decodable {
        guard let decodedValue = try? self.decodeIfPresent(Type, forKey: key) else {
            return try self.decodeIfString(Type, forKey: key)
        }
        
        return decodedValue
    }
    
    func decodeIfString<T>(_ Type: T.Type,
                           forKey key: KeyedDecodingContainer<Key>.Key) throws -> T? where T: Decodable {
        guard let string = try? self.decode(String.self,
                                            forKey: key) else {
            log("decodeIfString: could not parse string type.")
            return nil
        }
        
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        
        let newDecoder = getStitchDecoder()
        
        do {
            let result = try newDecoder.decode(T.self, from: data)
            return result
        } catch {
            throw StitchAIParsingError.decodeObjectFromString(string, error.localizedDescription)
        }
    }
}

extension PortValue {
    init?(decoderContainer: KeyedDecodingContainer<Step.CodingKeys>,
          type: UserVisibleType) throws {
        let portValueType = type.portValueTypeForStitchAI
        
        guard let decodedValue = try decoderContainer
            .decodeIfPresentSitchAI(portValueType, forKey: .value) else {
            // No value
            return nil
        }
        
        let value = try type.coerceToPortValueForStitchAI(from: decodedValue)
        self = value
    }
}

extension NodeIOPortType {
    // TODO: `LLMStepAction`'s `port` parameter does not yet properly distinguish between input vs output?
    // Note: the older LLMAction port-string-parsing logic was more complicated?
    init(stringValue: String) throws {
        let port = stringValue
  
        if let portId = Int(port) {
            // could be patch input/output OR layer output
            self = .portIndex(portId)
        } else if let portId = Double(port) {
            // could be patch input/output OR layer output
            self = .portIndex(Int(portId))
        } else if let layerInputPort: LayerInputPort = LayerInputPort.allCases.first(where: { $0.asLLMStepPort == port }) {
            let layerInputType = LayerInputType(layerInput: layerInputPort,
                                                // TODO: support unpacked with StitchAI
                                                portType: .packed)
            self = .keyPath(layerInputType)
        } else {
            throw StitchAIParsingError.portTypeDecodingError(port)
        }
    }
}

extension NodeType {
    init(llmString: String) throws {
        guard let match = NodeType.allCases.first(where: {
            $0.asLLMStepNodeType == llmString.toCamelCase()
        }) else {
            throw StitchAIParsingError.nodeTypeParsing(llmString)
        }
        
        self = match
    }
}

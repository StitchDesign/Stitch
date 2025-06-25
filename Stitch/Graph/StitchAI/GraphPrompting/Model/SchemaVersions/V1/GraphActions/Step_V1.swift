//
//  Step.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/25.
//

import Foundation
import SwiftUI
import SwiftyJSON
import StitchSchemaKit

// Note: `Step` as a type is basically one 'step' away from JSON,
// i.e. it's very generic and in majority of (or in all?) cases
// we actually want the more specific `StepActionable` type.
enum Step_V1: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V1
    static let documentVersion = StitchSchemaVersion._V32
    typealias StepType = StepType_V1.StepType
    typealias NodeType = StitchAIPortValue_V1.NodeType
    typealias PortValue = StitchAIPortValue_V1.PortValue
    typealias NodeKind = NodeKind_V32.NodeKind
    typealias Patch = Patch_V32.Patch
    typealias Layer = Layer_V32.Layer
    typealias NodeIOPortTypeVersion = NodeIOPortType_V32
    typealias NodeIOPortType = NodeIOPortTypeVersion.NodeIOPortType
    typealias LayerInputPort = LayerInputPort_V32.LayerInputPort
    typealias StitchAIUUid = StitchAIUUID_V1.StitchAIUUID
    typealias LayerNodeId = LayerNodeId_V32.LayerNodeId
    typealias NodeIOCoordinate = NodeIOCoordinate_V32.NodeIOCoordinate
    
    typealias PreviousInstance = Self.Step
    // MARK: - end
    
    public enum PatchOrLayer: Hashable, Codable {
        case patch(Step_V1.Patch), layer(Step_V1.Layer)
    }
    
    /// Represents a single step/action in the visual programming sequence
    struct Step: Hashable {
        // MARK: optional step type enables JavaScript node support for using same types
        var stepType: StepType        // Type of step (e.g., "add_node", "connect_nodes")
        var nodeId: StitchAIUUID?        // Identifier for the node
        var nodeName: PatchOrLayer?      // Display name for the node
        var port: NodeIOPortType?  // Port identifier (can be string or number)
        var fromPort: Int?  // Source port for connections
        var fromNodeId: StitchAIUUID?   // Source node for connections
        var toNodeId: StitchAIUUID?     // Target node for connections
        var value: PortValue? // Associated value data
        var valueType: NodeType?     // Type of the node
        var children: NodeIdOrderedSet? // Child nodes if this is a group
        
        init(stepType: StepType,
             nodeId: UUID? = nil,
             nodeName: PatchOrLayer? = nil,
             port: NodeIOPortType? = nil,
             fromPort: Int? = nil,
             fromNodeId: UUID? = nil,
             toNodeId: UUID? = nil,
             value: PortValue? = nil,
             valueType: NodeType? = nil,
             children: NodeIdOrderedSet? = nil) {
            self.stepType = stepType
            self.nodeId = .init(value: nodeId)
            self.nodeName = nodeName
            self.port = port
            self.fromPort = fromPort
            self.fromNodeId = .init(value: fromNodeId)
            self.toNodeId = .init(value: toNodeId)
            self.value = value
            self.valueType = valueType
            self.children = children
        }
        
        enum CodingKeys: String, CodingKey {
            case stepType = "step_type"
            case nodeId = "node_id"
            case nodeName = "node_name"
            case port
            case fromPort = "from_port"
            case fromNodeId = "from_node_id"
            case toNodeId = "to_node_id"
            case value
            case valueType = "value_type"
            case children = "children"
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            // `encodeIfPresent` cleans up JSON by removing properties
            try container.encode(stepType.rawValue, forKey: .stepType)
            try container.encodeIfPresent(nodeId, forKey: .nodeId)
            try container.encodeIfPresent(nodeName?.asLLMStepNodeName, forKey: .nodeName)
            
            // Handle port encoding differently based on type
            if let portValue = port?.asLLMStepPort() {
                if let intValue = portValue as? Int {
                    try container.encodeIfPresent(intValue, forKey: .port)
                } else if let stringValue = portValue as? String {
                    try container.encodeIfPresent(stringValue, forKey: .port)
                }
            }
            
            try container.encodeIfPresent(fromPort, forKey: .fromPort)
            try container.encodeIfPresent(fromNodeId, forKey: .fromNodeId)
            try container.encodeIfPresent(toNodeId, forKey: .toNodeId)
            try container.encodeIfPresent(valueType?.asLLMStepNodeType, forKey: .valueType)
            try container.encodeIfPresent(children, forKey: .children)
            
            if let valueCodable = value?.anyCodable {
                try container.encodeIfPresent(valueCodable, forKey: .value)
            }
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let stepTypeString = try container.decode(String.self, forKey: .stepType)
            
            guard let stepType = StepType(rawValue: stepTypeString) else {
                throw StitchAIParsingError.stepActionDecoding(stepTypeString)
            }
            
            self.stepType = stepType
            self.nodeId = try container.decodeIfPresent(StitchAIUUID.self, forKey: .nodeId)
            self.fromNodeId = try container.decodeIfPresent(StitchAIUUID.self, forKey: .fromNodeId)
            self.toNodeId = try container.decodeIfPresent(StitchAIUUID.self, forKey: .toNodeId)
            self.fromPort = try container.decodeIfPresent(Int.self, forKey: .fromPort)
            
            if let nodeNameString = try container.decodeIfPresent(String.self, forKey: .nodeName) {
                self.nodeName = try .fromLLMNodeName(nodeNameString)
            }
            
            if let portString = try? container.decodeIfPresent(String.self, forKey: .port) {
                self.port = try Step_V1.NodeIOPortType(stringValue: portString)
            } else if let portInt = try? container.decodeIfPresent(Int.self, forKey: .port) {
                self.port = Step_V1.NodeIOPortType.portIndex(portInt)
            }

            // Important: Layer Groups do not have node type, so we must decode children
            self.children = try container.decodeIfPresent(NodeIdOrderedSet.self, forKey: .children)
            
            // MARK: node type required for everything below this line
            guard let nodeTypeString = try container.decodeIfPresent(String.self, forKey: .valueType) else {
                return
            }
            
            guard let nodeType = NodeType(llmString: nodeTypeString) else {
                throw StitchAIParsingError.nodeTypeParsing(nodeTypeString)
            }
            
            self.valueType = nodeType
            
            // Parse value given node type
            do {
                self.value = try StitchAIPortValue_V1
                    .PortValue(decoderContainer: container,
                               type: nodeType)
            } catch {
                log("Step decoding error for step: \(stepTypeString)\nWith error: \(error.localizedDescription)")
                
                if let stitchAIError = error as? StitchAIManagerError {
                    throw stitchAIError
                } else {
                    throw StitchAIParsingError.portValueDecodingError(error.localizedDescription)
                }
            }
        }
    }
}

extension Step_V1.Step: StitchVersionedCodable {
    public init(previousInstance: Step_V1.PreviousInstance) {
        fatalError()
    }
}

extension Step_V1.NodeIOPortType {
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
        } else if let layerInputPort: Step_V1.LayerInputPort = Step_V1.LayerInputPort.allCases.first(where: { $0.asLLMStepPort == port }) {
            let layerInputType = Step_V1.NodeIOPortTypeVersion
                .LayerInputType(layerInput: layerInputPort,
                                // TODO: support unpacked with StitchAI
                                portType: .packed)
            self = .keyPath(layerInputType)
        } else {
            throw StitchAIParsingError.portTypeDecodingError(port)
        }
    }
}

extension Step_V1.Step: CustomStringConvertible {
    /// Provides detailed string representation of a Step
    public var description: String {
        return """
        Step(
            stepType: "\(stepType)",
            nodeId: \(nodeId?.value.uuidString ?? "nil"),
            nodeName: \(nodeName?.asLLMStepNodeName ?? "nil"),
            port: \(port?.asLLMStepPort() ?? "nil"),
            fromNodeId: \(fromNodeId?.value.uuidString ?? "nil"),
            toNodeId: \(toNodeId?.value.uuidString ?? "nil"),
            value: \(String(describing: value)),
            nodeType: \(valueType?.display ?? "nil")
            children: \(children?.description ?? "nil")
        )
        """
    }
}

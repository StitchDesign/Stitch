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
enum Step_V0: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V0
    static let documentVersion = StitchSchemaVersion._V31
    typealias StepType = StepType_V0.StepType
    typealias NodeType = StitchAIPortValue_V0.NodeType
    typealias PortValue = StitchAIPortValue_V0.PortValue
    typealias NodeKind = NodeKind_V31.NodeKind
    typealias Patch = Patch_V31.Patch
    typealias Layer = Layer_V31.Layer
    typealias NodeIOPortTypeVersion = NodeIOPortType_V31
    typealias NodeIOPortType = NodeIOPortTypeVersion.NodeIOPortType
    typealias LayerInputPort = LayerInputPort_V31.LayerInputPort
    typealias StitchAIUUid = StitchAIUUID_V0.StitchAIUUID
    typealias PatchOrLayer = PatchOrLayer_V31.PatchOrLayer
    typealias LayerNodeId = LayerNodeId_V31.LayerNodeId
    typealias NodeKindDescribable = NodeKindDescribable_V31.NodeKindDescribable
    typealias NodeIOCoordinate = NodeIOCoordinate_V31.NodeIOCoordinate
    
    typealias PreviousInstance = Self.Step
    // MARK: - end
    
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
        var children: NodeIdSet? // Child nodes if this is a group
        
        init(stepType: StepType,
             nodeId: UUID? = nil,
             nodeName: PatchOrLayer? = nil,
             port: NodeIOPortType? = nil,
             fromPort: Int? = nil,
             fromNodeId: UUID? = nil,
             toNodeId: UUID? = nil,
             value: PortValue? = nil,
             valueType: NodeType? = nil,
             children: NodeIdSet? = nil) {
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
                self.port = try NodeIOPortType(stringValue: portString)
            } else if let portInt = try? container.decodeIfPresent(Int.self, forKey: .port) {
                self.port = NodeIOPortType.portIndex(portInt)
            }

            // Important: Layer Groups do not have node type, so we must decode children
            self.children = try container.decodeIfPresent(NodeIdSet.self, forKey: .children)
            
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
                self.value = try CurrentStitchAIPortValue
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

extension Step_V0.Step: StitchVersionedCodable {
    public init(previousInstance: Step_V0.PreviousInstance) {
        fatalError()
    }
}


extension Step {
    // Note: it's slightly awkward in Swift to handle protocol-implementing concrete types
    func parseAsStepAction() -> Result<any StepActionable, StitchAIStepHandlingError> {
        switch self.stepType {
        case .addNode:
            return StepActionAddNode.fromStep(self).map { $0 as any StepActionable}
        case .connectNodes:
            return StepActionConnectionAdded.fromStep(self).map { $0 as any StepActionable}
        case .changeValueType:
            return StepActionChangeValueType.fromStep(self).map { $0 as any StepActionable}
        case .setInput:
            return StepActionSetInput.fromStep(self).map { $0 as any StepActionable}
        case .sidebarGroupCreated:
            return StepActionLayerGroupCreated.fromStep(self).map { $0 as any StepActionable}
//        case .editJSNode:
//            return StepActionEditJSNode.fromStep(self).map { $0 as any StepActionable}
        }
    }
}

extension Stitch.Step: CustomStringConvertible {
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

//
//  Step.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/25.
//

import Foundation
import SwiftUI
import SwiftyJSON

//protocol StitchAIStepActionable: Hashable, Codable {
//    static var stepType: StepType { get }
//    
//    // Type of step (e.g., "add_node", "connect_nodes")
//    var stepType: StepType  { get set }
//    
//    // Identifier for the node
//    var nodeId: UUID? { get set }
//    
//    // Display name for the node
//    var nodeName: PatchOrLayer? { get set }
//    
//    // Port identifier (can be string or number)
//    var port: NodeIOPortType? { get set }
//    
//    // Source port for connections
//    var fromPort: Int? { get set }
//    
//    // Source node for connections
//    var fromNodeId: UUID? { get set }
//    
//    // Target node for connections
//    var toNodeId: UUID? { get set }
//    
//    // Associated value data
//    var value: PortValue? { get set }
//    
//    // Type of the node
//    var nodeType: NodeType? { get set }
//    
//    
//    init(nodeId: StitchAIUUID?,
//         nodeName: PatchOrLayer?,
//         port: NodeIOPortType?,
//         fromPort: Int?,
//         fromNodeId: UUID?,
//         toNodeId: UUID?,
//         value: PortValue?,
//         nodeType: NodeType?
//    )
//}
//
//extension StitchAIStepActionable {
//    var toStep: Step {
//        Step(stepType: Self.stepType,
//             nodeId: self.nodeId != nil ? .init(self.nodeId!) : nil,
//             nodeName: self.nodeName,
//             port: self.port,
//             fromPort: self.fromPort,
//             fromNodeId: self.fromNodeId,
//             toNodeId: self.toNodeId,
//             value: self.value,
//             nodeType: self.nodeType)
//    }
//}

/// Represents a single step/action in the visual programming sequence
struct Step: Hashable {
    var stepType: StepType        // Type of step (e.g., "add_node", "connect_nodes")
    var nodeId: StitchAIUUID?        // Identifier for the node
    var nodeName: PatchOrLayer?      // Display name for the node
    var port: NodeIOPortType?  // Port identifier (can be string or number)
    var fromPort: Int?  // Source port for connections
    var fromNodeId: StitchAIUUID?   // Source node for connections
    var toNodeId: StitchAIUUID?     // Target node for connections
    var value: PortValue? // Associated value data
    var nodeType: NodeType?     // Type of the node
    
    init(stepType: StepType,
         nodeId: UUID? = nil,
         nodeName: PatchOrLayer? = nil,
         port: NodeIOPortType? = nil,
         fromPort: Int? = nil,
         fromNodeId: UUID? = nil,
         toNodeId: UUID? = nil,
         value: PortValue? = nil,
         nodeType: NodeType? = nil) {
        self.stepType = stepType
        self.nodeId = .init(value: nodeId)
        self.nodeName = nodeName
        self.port = port
        self.fromPort = fromPort
        self.fromNodeId = .init(value: fromNodeId)
        self.toNodeId = .init(value: toNodeId)
        self.value = value
        self.nodeType = nodeType
    }
}

extension Step: Codable {
    
    enum CodingKeys: String, CodingKey {
        case stepType = "step_type"
        case nodeId = "node_id"
        case nodeName = "node_name"
        case port
        case fromPort = "from_port"
        case fromNodeId = "from_node_id"
        case toNodeId = "to_node_id"
        case value
        case nodeType = "node_type"
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // `encodeIfPresent` cleans up JSON by removing properties
        
        try container.encodeIfPresent(stepType.rawValue, forKey: .stepType)
        try container.encodeIfPresent(nodeId, forKey: .nodeId)
        try container.encodeIfPresent(nodeName?.asNodeKind.asLLMStepNodeName, forKey: .nodeName)
        try container.encodeIfPresent(port?.asLLMStepPort(), forKey: .port)
        try container.encodeIfPresent(fromPort, forKey: .fromPort)
        try container.encodeIfPresent(fromNodeId, forKey: .fromNodeId)
        try container.encodeIfPresent(toNodeId, forKey: .toNodeId)
        try container.encodeIfPresent(nodeType?.asLLMStepNodeType, forKey: .nodeType)
        
        if let valueCodable = value?.anyCodable {
            try container.encodeIfPresent(valueCodable, forKey: .value)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let stepTypeString = try container.decode(String.self, forKey: .stepType)
        
        guard let stepType = StepType(rawValue: stepTypeString) else {
            throw StitchAICodingError.stepDecoding
        }
        
        self.stepType = stepType
        self.nodeId = try container.decodeIfPresent(StitchAIUUID.self, forKey: .nodeId)
        self.fromNodeId = try container.decodeIfPresent(StitchAIUUID.self, forKey: .fromNodeId)
        self.toNodeId = try container.decodeIfPresent(StitchAIUUID.self, forKey: .toNodeId)
        
        if let nodeNameString = try? container.decode(String?.self, forKey: .nodeName) {
            self.nodeName = .fromLLMNodeName(nodeNameString)
        }
        
        if let portString = try? container.decode(String?.self, forKey: .port) {
            self.port = NodeIOPortType(stringValue: portString)
        }
        
        self.fromPort = try? container.decode(Int?.self, forKey: .fromPort)

        guard let nodeTypeString = try? container.decode(String?.self, forKey: .nodeType),
              let nodeType = NodeType(llmString: nodeTypeString) else {
            return
        }
        self.nodeType = nodeType
        
        // Parse value given node type
        self.value = try? PortValue(decoderContainer: container,
                                    type: nodeType)
    }
}

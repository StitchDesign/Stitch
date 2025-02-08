//
//  Step.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/25.
//

import Foundation
import SwiftUI
import SwiftyJSON

/// Represents a single step/action in the visual programming sequence
struct Step: Equatable, Hashable {
    var stepType: StepType        // Type of step (e.g., "add_node", "connect_nodes")
    var nodeId: UUID?        // Identifier for the node
    var nodeName: PatchOrLayer?      // Display name for the node
    var port: NodeIOPortType?  // Port identifier (can be string or number)
    var fromPort: Int?  // Source port for connections
    var fromNodeId: UUID?   // Source node for connections
    var toNodeId: UUID?     // Target node for connections
    var value: PortValue? // Associated value data
    var nodeType: NodeType?     // Type of the node
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
        
        try container.encode(stepType.rawValue, forKey: .stepType)
        try container.encode(nodeId?.description, forKey: .nodeId)
        try container.encode(nodeName?.asNodeKind.asLLMStepNodeName, forKey: .nodeName)
        try container.encode(port?.asLLMStepPort(), forKey: .port)
        try container.encode(fromPort, forKey: .fromPort)
        try container.encode(fromNodeId?.description, forKey: .fromNodeId)
        try container.encode(toNodeId?.description, forKey: .toNodeId)
        try container.encode(nodeType?.asLLMStepNodeType, forKey: .nodeType)
        
        if let valueCodable = value?.anyCodable {
            try container.encode(valueCodable, forKey: .value)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let stepTypeString = try container.decode(String.self, forKey: .stepType)
        
        guard let stepType = StepType(rawValue: stepTypeString) else {
            throw StitchAICodingError.stepDecoding
        }
        
        self.stepType = stepType
        
        if let nodeIdString = try? container.decode(String?.self, forKey: .nodeId) {
            self.nodeId = UUID(uuidString: nodeIdString)
        }
        if let fromNodeIdString = try? container.decode(String?.self, forKey: .fromNodeId) {
            self.fromNodeId = UUID(uuidString: fromNodeIdString)
        }
        if let toNodeIdString = try? container.decode(String?.self, forKey: .toNodeId) {
            self.toNodeId = UUID(uuidString: toNodeIdString)
        }
        
        if let nodeNameString = try? container.decode(String?.self, forKey: .nodeName) {
            self.nodeName = PatchOrLayer(nodeName: nodeNameString)
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

/// Wrapper for handling values that could be either string or number
struct StringOrNumber: Equatable, Hashable {
    let value: String          // Normalized string representation of the value
}

extension StringOrNumber: Codable {
    /// Encodes the value as a string
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }
    
    /// Decodes a value that could be string, int, double, or JSON
    /// - Parameter decoder: The decoder to read from
    /// - Throws: DecodingError if value cannot be converted to string
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try decoding as different types, converting each to string
        if let intValue = try? container.decode(Int.self) {
            log("StringOrNumber: Decoder: tried int")
            self.value = String(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            log("StringOrNumber: Decoder: tried double")
            self.value = String(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            log("StringOrNumber: Decoder: tried string")
            self.value = stringValue
        } else if let jsonValue = try? container.decode(JSON.self) {
            log("StringOrNumber: Decoder: had json \(jsonValue)")
            self.value = jsonValue.description
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String, Int, or Double"
                )
            )
        }
    }
}

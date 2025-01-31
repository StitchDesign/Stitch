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
struct Step: Equatable, Codable, Hashable {
    var stepType: String        // Type of step (e.g., "add_node", "connect_nodes")
    var nodeId: String?        // Identifier for the node
    var nodeName: String?      // Display name for the node
    var port: StringOrNumber?  // Port identifier (can be string or number)
    var fromPort: StringOrNumber?  // Source port for connections
    var fromNodeId: String?   // Source node for connections
    var toNodeId: String?     // Target node for connections
    var value: JSONFriendlyFormat? // Associated value data
    var nodeType: String?     // Type of the node
    
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

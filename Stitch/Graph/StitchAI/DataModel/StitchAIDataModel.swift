//
//  StitchAIDataModel.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation

struct OpenAIResponse: Codable {
    var choices: [Choice]
}

struct Choice: Codable {
    var message: MessageStruct
}

struct MessageStruct: Codable {
    var content: String
    var refusal: String?
    
    func parseContent() throws -> ContentJSON {
        guard let contentData = content.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid content data"))
        }
        return try JSONDecoder().decode(ContentJSON.self, from: contentData)
    }
}

struct ContentJSON: Codable {
    var steps: [Step]
}

typealias LLMStepAction = Step
typealias LLMStepActions = [LLMStepAction]

// TODO: use several different data structures with more specific parameters, rather than a single data structure with tons of optional parameters
// TODO: make parameters more specific? e.g. `nodeName` should be `PatchOrLayer?` instead of `String?`

// should actually be an enum like LLMAction ? So that we can avoid the many `nil` parameters?
// worst case, keep this data structure for decoding OpenAI json schema, and easily translate between these two ?
struct Step: Equatable, Codable {
    var stepType: String
    var nodeId: String?
    var nodeName: String?
    
    // NOTE: this is currently ALWAYS the input port (for edge-connection, for set-input etc.)
    // We currently assume that an edge goes out from a patch's first output.
    var port: StringOrNumber?  // Updated to handle String or Int
    
    var fromNodeId: String?
    var toNodeId: String?
    var value: StringOrNumber?  // Updated to handle String or Int
    var nodeType: String?
    
    enum CodingKeys: String, CodingKey {
        case stepType = "step_type"
        case nodeId = "node_id"
        case nodeName = "node_name"
        case port
        case fromNodeId = "from_node_id"
        case toNodeId = "to_node_id"
        case value
        case nodeType = "node_type"
    }
}

struct StringOrNumber: Equatable {
    let value: String
}

// Note: OpenAI may send us a JSON with e.g. a `port` key that either a json-number or a string; so we have slighlty
// TODO: Better?: force OpenAI to return a string in the json, always?
extension StringOrNumber: Codable {
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            log("StringOrNumber: Decoder: tried int")
            self.value = String(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            log("StringOrNumber: Decoder: tried double")
            self.value = String(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            log("StringOrNumber: Decoder: tried string")
            self.value = stringValue
        } else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String, Int, or Double"))
        }
    }
}

enum StepType: String, Equatable, Codable {
    case addNode = "add_node"
    case addLayerInput = "add_layer_input"
    case connectNodes = "connect_nodes"
    case changeNodeType = "change_node_type"
    case setInput = "set_input"
}

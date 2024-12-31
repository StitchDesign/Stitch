//
//  StitchAIDataModel.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation
import SwiftyJSON

struct OpenAIResponse: Codable {
    var id: String
    var object: String
    var created: Int
    var model: String
    var choices: [Choice]
    var usage: Usage
    var systemFingerprint: String
    
    enum CodingKeys: String, CodingKey {
        case id, object, created, model, choices, usage
        case systemFingerprint = "system_fingerprint"
    }
}

struct Usage: Codable {
    var promptTokens: Int
    var completionTokens: Int
    var totalTokens: Int
    var promptTokensDetails: TokenDetails
    var completionTokensDetails: CompletionTokenDetails
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case promptTokensDetails = "prompt_tokens_details"
        case completionTokensDetails = "completion_tokens_details"
    }
}

struct TokenDetails: Codable {
    var cachedTokens: Int
    var audioTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
        case audioTokens = "audio_tokens"
    }
}

struct CompletionTokenDetails: Codable {
    var reasoningTokens: Int
    var audioTokens: Int
    var acceptedPredictionTokens: Int
    var rejectedPredictionTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case reasoningTokens = "reasoning_tokens"
        case audioTokens = "audio_tokens"
        case acceptedPredictionTokens = "accepted_prediction_tokens"
        case rejectedPredictionTokens = "rejected_prediction_tokens"
    }
}

struct Choice: Codable {
    var index: Int
    var message: MessageStruct
    var logprobs: JSON?
    var finishReason: String
    
    enum CodingKeys: String, CodingKey {
        case index, message, logprobs
        case finishReason = "finish_reason"
    }
}

struct MessageStruct: Codable {
    var role: String
    var content: String
    var refusal: String?
    
    func parseContent() throws -> ContentJSON {
        // First, print the raw content for debugging
        print("Raw content: \(content)")
        
        guard let contentData = content.data(using: .utf8) else {
            print("Debug - raw content: \(content)")
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid content data"))
        }
        
        // Create a decoder with custom configuration
        let decoder = JSONDecoder()
        
        // Try to decode the full ContentJSON structure
        do {
            let result = try decoder.decode(ContentJSON.self, from: contentData)
            print("Successfully decoded with \(result.jsonSchema.steps.count) actions")
            return result
        } catch {
            print("Detailed decoding error: \(error)")
            throw error
        }
    }
}

struct ContentJSON: Codable {
    var jsonSchema: JSONSchema
    
    enum CodingKeys: String, CodingKey {
        case jsonSchema = "json_schema"
    }
}

struct JSONSchema: Codable {
    var name: String?
    var steps: [Step]
    var strict: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name, steps, strict, schema
    }
    
    enum SchemaCodingKeys: String, CodingKey {
        case steps
    }
    
    // Add custom decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode steps directly first
        if let directSteps = try? container.decode([Step].self, forKey: .steps) {
            self.steps = directSteps
            self.name = try? container.decode(String.self, forKey: .name)
            self.strict = try? container.decode(Bool.self, forKey: .strict)
            return
        }
        
        // If that fails, try to decode from nested schema
        if let schema = try? container.nestedContainer(keyedBy: SchemaCodingKeys.self, forKey: .schema) {
            self.steps = try schema.decode([Step].self, forKey: .steps)
            self.name = try? container.decode(String.self, forKey: .name)
            self.strict = try? container.decode(Bool.self, forKey: .strict)
            return
        }
        
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Unable to decode steps from either direct or nested format"
        ))
    }
    
    // Add custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(steps, forKey: .steps)
        try container.encode(strict, forKey: .strict)
    }
}


struct Schema: Codable {
    var steps: [Step]
}

struct Step: Equatable, Codable {
    var stepType: String
    var nodeId: String?
    var nodeName: String?
    
    // NOTE: this is currently ALWAYS the input port (for edge-connection, for set-input etc.)
    // We currently assume that an edge goes out from a patch's first output.
    var port: StringOrNumber?
    
    var fromPort: Int?
    
    var fromNodeId: String?
    var toNodeId: String?
    
//    var value: StringOrNumber?  // Updated to handle String or Int
    var value: JSONFriendlyFormat?
    
    var nodeType: String?
    
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
        } else if let jsonValue = try? container.decode(JSON.self) {
            log("StringOrNumber: Decoder: had json \(jsonValue)")
            // escaped string?
            self.value = jsonValue.description
        }
        else {
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

typealias LLMStepAction = Step
typealias LLMStepActions = [LLMStepAction]

// TODO: use several different data structures with more specific parameters, rather than a single data structure with tons of optional parameters
// TODO: make parameters more specific? e.g. `nodeName` should be `PatchOrLayer?` instead of `String?`

// should actually be an enum like LLMAction ? So that we can avoid the many `nil` parameters?
// worst case, keep this data structure for decoding OpenAI json schema, and easily translate between these two ?

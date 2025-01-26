//
//  StitchAIDataModel.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//
// This file defines the data structures for handling OpenAI API responses and managing
// visual programming actions in the Stitch app. It includes models for parsing JSON responses,
// handling token usage metrics, and managing step-based visual programming operations.

import Foundation
import SwiftyJSON

/// Represents the complete response structure from OpenAI's API
struct OpenAIResponse: Codable {
    var id: String                // Unique identifier for the API response
    var object: String            // Type of object returned by the API
    var created: Int             // Unix timestamp when the response was created
    var model: String            // Name of the OpenAI model used
    var choices: [Choice]        // Array of response alternatives (usually contains one choice)
    var usage: Usage             // Token usage statistics for the request
    var systemFingerprint: String // System identification string
    
    enum CodingKeys: String, CodingKey {
        case id, object, created, model, choices, usage
        case systemFingerprint = "system_fingerprint"
    }
}

/// Tracks token usage metrics for API requests
struct Usage: Codable {
    var promptTokens: Int         // Number of tokens used in the prompt
    var completionTokens: Int     // Number of tokens in the completion
    var totalTokens: Int         // Total tokens used in the request
    var promptTokensDetails: TokenDetails  // Detailed breakdown of prompt token usage
    var completionTokensDetails: CompletionTokenDetails // Detailed completion token stats
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case promptTokensDetails = "prompt_tokens_details"
        case completionTokensDetails = "completion_tokens_details"
    }
}

/// Detailed breakdown of token usage for prompts
struct TokenDetails: Codable {
    var cachedTokens: Int        // Number of tokens retrieved from cache
    var audioTokens: Int         // Number of tokens used for audio processing
    
    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
        case audioTokens = "audio_tokens"
    }
}

/// Detailed breakdown of token usage for completions
struct CompletionTokenDetails: Codable {
    var reasoningTokens: Int              // Tokens used for reasoning/logic
    var audioTokens: Int                  // Tokens used for audio processing
    var acceptedPredictionTokens: Int     // Tokens from accepted predictions
    var rejectedPredictionTokens: Int     // Tokens from rejected predictions
    
    enum CodingKeys: String, CodingKey {
        case reasoningTokens = "reasoning_tokens"
        case audioTokens = "audio_tokens"
        case acceptedPredictionTokens = "accepted_prediction_tokens"
        case rejectedPredictionTokens = "rejected_prediction_tokens"
    }
}

/// Represents a single response choice from the API
struct Choice: Codable {
    var index: Int               // Index of this choice in the response array
    var message: MessageStruct   // The actual response message
    var logprobs: JSON?         // Log probabilities (if requested)
    var finishReason: String    // Reason why the API stopped generating
    
    enum CodingKeys: String, CodingKey {
        case index, message, logprobs
        case finishReason = "finish_reason"
    }
}

/// Structure representing a message in the API response
struct MessageStruct: Codable {
    var role: String            // Role of the message (e.g., "assistant", "user")
    var content: String         // Actual content of the message
    var refusal: String?       // Optional refusal message if content was denied
    
    /// Attempts to parse the message content into structured JSON
    /// - Throws: DecodingError if content cannot be parsed
    /// - Returns: Parsed ContentJSON structure
    func parseContent() throws -> ContentJSON {
        guard let contentData = content.data(using: .utf8) else {
            print("Debug - raw content: \(content)")
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "Failed to convert content string to data"
            ))
        }
        
        let decoder = JSONDecoder()
        
        do {
            let result = try decoder.decode(ContentJSON.self, from: contentData)
            print("Successfully decoded with \(result.steps.count) steps")
            return result
        } catch {
            print("Detailed decoding error: \(error)")
            throw error
        }
    }
}

/// Represents the structured content of a message
struct ContentJSON: Codable {
    var steps: [Step] // Array of steps in the visual programming sequence
}

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

/// Enumeration of possible step types in the visual programming system
enum StepType: String, Equatable, Codable {
    case addNode = "add_node"
    case addLayerInput = "add_layer_input"
    case connectNodes = "connect_nodes"
    case changeNodeType = "change_node_type"
    case setInput = "set_input"
}

// Type aliases for improved code readability
typealias LLMStepAction = Step
typealias LLMStepActions = [LLMStepAction]

// TODO: use several different data structures with more specific parameters,
// rather than a single data structure with tons of optional parameters
// TODO: make parameters more specific? e.g. `nodeName` should be `PatchOrLayer?`
// instead of `String?`

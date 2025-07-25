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
import StitchSchemaKit
import SwiftyJSON

/// Represents the complete response structure from OpenAI's API
struct OpenAIResponse: Codable {
    var id: String                // Unique identifier for the API response
    var object: String            // Type of object returned by the API
    var created: Int             // Unix timestamp when the response was created
    var model: String            // Name of the OpenAI model used
    var choices: [OpenAIChoice]        // Array of response alternatives (usually contains one choice)
    var usage: Usage             // Token usage statistics for the request
    var systemFingerprint: String? // System identification string
    var serviceTier: String
    
    enum CodingKeys: String, CodingKey {
        case id, object, created, model, choices, usage
        case systemFingerprint = "system_fingerprint"
        case serviceTier = "service_tier"
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
struct OpenAIChoice: Codable {
    var index: Int               // Index of this choice in the response array
    var message: OpenAIMessage   // The actual response message
    var logprobs: JSON?         // Log probabilities (if requested)
    var finishReason: String    // Reason why the API stopped generating
    
    enum CodingKeys: String, CodingKey {
        case index, message, logprobs
        case finishReason = "finish_reason"
    }
}

/// Structure representing a message in the API response
struct OpenAIMessage: Codable {
    var role: OpenAIRole            // Role of the message (e.g., "assistant", "user")
    var content: String?         // Actual content of the message
//    var content: [OpenAIMessageContent]         // Actual content of the message
    var tool_calls: [OpenAIToolCallResponse]?
    var tool_call_id: String?
    var name: String?
    var refusal: String?       // Optional refusal message if content was denied
    var annotations: [String]?  // Optional annotations
}

struct OpenAIToolCallResponse: Codable {    
    var id: String
    var type: String
    var function: OpenAIFunctionResponse
}

struct OpenAIFunctionResponse: Codable {
    var name: String
    var arguments: String
}

extension StitchAIRequestable {
    /// Attempts to parse the message content into structured JSON
    /// - Throws: DecodingError if content cannot be parsed
    /// - Returns: Parsed ContentJSON structure
    static func parseOpenAIResponse(message: OpenAIMessage) throws -> Self.InitialDecodedResult {        
        guard let content = message.content,
              let contentData = content.data(using: .utf8) else {
            print("Debug - raw content: \(message)")
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "Failed to convert content string to data"
            ))
        }
        
        let decoder = getStitchDecoder()
        
        if Self.InitialDecodedResult.self == String.self,
           let contentString = content as? Self.InitialDecodedResult {
            return contentString
        }
        
        do {
            let result = try decoder.decode(Self.InitialDecodedResult.self, from: contentData)
            print("MessageStruct: successfully decoded with:\n\((try? result.encodeToPrintableString()) ?? "")")
            return result
        } catch let error as StitchAIManagerError {
            throw error
        } catch {
            print("parseOpenAIResponse error: \(error)")
            throw StitchAIManagerError.contentDataDecodingError(content, error.localizedDescription)
        }
    }
}

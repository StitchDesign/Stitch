//
//  StitchAIManagerError.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/12/25.
//

import SwiftUI
import StitchSchemaKit

// MARK: An error we encounter when trying to parse or validate a Step

enum StitchAIStepHandlingError: Error {
    case stepActionDecoding(String)
    case stepDecoding(StepType, Step)
    case actionValidationError(String)
}

extension StitchAIStepHandlingError {
    var shouldRetryRequest: Bool {
        switch self {
        case .stepActionDecoding, .stepDecoding, .actionValidationError:
            return true
        }
    }
}

// An error encountered when trying to validate
extension StitchAIStepHandlingError: CustomStringConvertible {
    var description: String {
        switch self {
        case .stepActionDecoding(let string):
            return "Unable to parse action step type from: \(string)"
        case .stepDecoding(let stepType, let step):
            return "Unable to decode: \(stepType) with step payload:\n\(step)"
        case .actionValidationError(let string):
            return "Action validation error: \(string)"
        }
    }
}


// MARK: An error we encounter when opening or closing a stream request
 
enum StitchAIStreamingError: Error {
    case timeout
    case maxTimeouts
    case maxRetriesError(Int, String)
    case currentlyInARetryDelay
    case rateLimit
    case invalidURL
    case requestCancelled // e.g. by user, or because stream naturally completed
    case internetConnectionFailed
    case other(Error)
}

extension StitchAIStreamingError {
    var shouldRetryRequest: Bool {
        switch self {
        case .timeout, .rateLimit:
            return true
        case .maxTimeouts, .maxRetriesError, .currentlyInARetryDelay, .invalidURL, .requestCancelled, .internetConnectionFailed, .other:
            return false // under these scenarios, we do not re-attempt the request
        }
    }
}

extension StitchAIStreamingError: CustomStringConvertible {
    var description: String {
        switch self {
        case .timeout:
            return "Server timed out."
        case .maxTimeouts:
            return "We hit the max number of allowed time outs."
        case .maxRetriesError(let maxRetries, let errorDescription):
            return "Request failed after \(maxRetries) attempts. Last error:\n\(errorDescription)"
        case .currentlyInARetryDelay:
            return "Could not start a request because we are currently waiting for a retry delay to finish."
        case .rateLimit:
            return "Rate limited."
        case .invalidURL:
            return "Invalid URL"
        case .requestCancelled:
            return "Request either canceled by user or stream successfully completed."
        case .internetConnectionFailed:
            return "No internet connection. Please try again when your connection is restored."
        case .other(let error):
            return "OpenAI Request error: \(error.localizedDescription)"
            
        }
    }
}

// MARK: an error when we attempted to parse a JSON response from OpenAI

// TODO: do we show any of these to the user? If not, perhaps better to "crash on debug, return nil on prod" ?
enum StitchAIParsingError: Error {
    case typeCasting
    case decodeObjectFromString(String, String)
    case portValueDecodingError(String)
    case nodeTypeParsing(String)
    case portTypeDecodingError(String)
    case stepActionDecoding(String)
    case nodeNameParsing(String)
}

extension StitchAIParsingError: CustomStringConvertible {
    var description: String {
        
        switch self {
            
        case .typeCasting:
            return "Unable to cast type for object."
        case .decodeObjectFromString(let stringObject, let errorResponse):
            return "Unable to decode object from string: \(stringObject)\nError: \(errorResponse)"
        case .nodeTypeParsing(let string):
            return "Could not parse node type: \(string)"
        case .portTypeDecodingError(let port):
            return "Could not decode node's port from: \(port)"
        case .portValueDecodingError(let errorResponse):
            return "Unable to decode PortValue with error: \(errorResponse)"
        case .stepActionDecoding(let string):
            return "Unable to parse action step type from: \(string)"
        case .nodeNameParsing(let string):
            return "Could not parse node name: \(string)"
        }
        
    }
}



// MARK: Misc/legacy errors

// TODO: which are just for us developers (to be logged), vs actionable for the user?
enum StitchAIManagerError: Error {
    case contentDataDecodingError(String, String)
    case other(OpenAIRequest, Error)
}

extension StitchAIManagerError: CustomStringConvertible {
    var description: String {
        switch self {
        case .contentDataDecodingError(let contentData, let errorResponse):
            return "Unable to parse step actions from: \(contentData) with error: \(errorResponse)"
        case .other(_, let error):
            return "OpenAI Request error: \(error.localizedDescription)"
        }
    }
}

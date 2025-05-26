//
//  StitchAIManagerError.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/12/25.
//

import SwiftUI
import StitchSchemaKit

// An error we encounter when trying to parse or validate a Step
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

// An error we encounter when opening or closing a stream request
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



// TODO: a smaller sub-enum just for errors from "validating or applying Step/StepActionable"
// TODO: which are just for us developers (to be logged), vs actionable for the user?
enum StitchAIManagerError: Error {
    case documentNotFound(OpenAIRequest)
    case requestInProgress(OpenAIRequest)
    case maxRetriesError(Int, String)
    case invalidURL(OpenAIRequest)
    case jsonEncodingError(OpenAIRequest, Error)
    
    case requestCancelled(OpenAIRequest)
    
    // Show these as alerts to user ?
    case internetConnectionFailed(OpenAIRequest)
    case timeout(OpenAIRequest, String)
    case multipleTimeoutErrors(OpenAIRequest, String)
    
    case typeCasting
    case stepActionDecoding(String)
    case emptySuccessfulResponse
    
    case nodeNameParsing(String)
    case nodeTypeParsing(String)
    case contentDataDecodingError(String, String)
    case portValueDecodingError(String)
    case decodeObjectFromString(String, String)
    case structuredOutputsNotFound
    case apiResponseError
    case portTypeDecodingError(String)
    
    case invalidStreamingData
    
    case other(OpenAIRequest, Error)
}

extension StitchAIManagerError: CustomStringConvertible {
    var description: String {
        switch self {
        case .documentNotFound:
            return ""
        case .requestInProgress:
            return "A request is already in progress. Skipping this request."
        case .maxRetriesError(let maxRetries, let errorDescription):
            return "Request failed after \(maxRetries) attempts. Last error:\n\(errorDescription)"
        case .invalidURL:
            return "Invalid URL"
        case .jsonEncodingError(_, let error):
            return "Error encoding JSON: \(error.localizedDescription)"
        
        case .internetConnectionFailed:
            return "No internet connection. Please try again when your connection is restored."
        
        case .timeout(let _, let errorDescription):
            return "Server timed out. Last captured error:\n\(errorDescription)"
        
        case .multipleTimeoutErrors(_, let errorDescription):
            return "Stitch AI failed on multiple requests. Last captured error:\n\(errorDescription)"
        
            
        case .other(_, let error):
            return "OpenAI Request error: \(error.localizedDescription)"
        case .requestCancelled(_):
            return ""
        case .typeCasting:
            return "Unable to cast type for object."
        case .stepActionDecoding(let string):
            return "Unable to parse action step type from: \(string)"
        case .emptySuccessfulResponse:
            return "StitchAI JSON parsing failed: No choices available"
        case .nodeNameParsing(let string):
            return "Could not parse node name: \(string)"
        case .nodeTypeParsing(let string):
            return "Could not parse node type: \(string)"
        case .contentDataDecodingError(let contentData, let errorResponse):
            return "Unable to parse step actions from: \(contentData) with error: \(errorResponse)"
        case .portValueDecodingError(let errorResponse):
            return "Unable to decode PortValue with error: \(errorResponse)"
        case .decodeObjectFromString(let stringObject, let errorResponse):
            return "Unable to decode object from string: \(stringObject)\nError: \(errorResponse)"
        case .structuredOutputsNotFound:
            return "Structured outputs file wasn't found."
        case .apiResponseError:
            return "API returned non-successful status code."
        case .portTypeDecodingError(let port):
            return "Could not decode node's port from: \(port)"
        case .invalidStreamingData:
            return "Invalid streaming data received from OpenAI"
        }
    }
}

extension StitchAIManagerError {
    var shouldDisplayModal: Bool {
        switch self {
        case .requestCancelled:
            return false
        case .documentNotFound,
             .internetConnectionFailed,
             .maxRetriesError,
             .multipleTimeoutErrors,
             .emptySuccessfulResponse,
             .invalidStreamingData,
             .apiResponseError,
             .jsonEncodingError,
             .invalidURL,
             .other:
            return true
        default:
            return false
        }
    }
}

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
    case typeMigrationFailed(any Encodable & Sendable)
    case sskMigrationFailed(SSKError)
    case other(any Error)
}

extension StitchAIStepHandlingError {
    var shouldRetryRequest: Bool {
        switch self {
        case .stepActionDecoding, .stepDecoding, .actionValidationError:
            return true
        case .typeMigrationFailed, .sskMigrationFailed, .other:
            return false
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
        case .typeMigrationFailed(let type):
            return "Unable to convert type: \(type)"
        case .sskMigrationFailed(let error):
            return "Migration failed for schema with error: \(error)"
        case .other(let error):
            return "\(error)"
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
    case urlRequestCreationFailure
    case markdownNotFound
    case other(Error)
}

extension StitchAIStreamingError {
    var shouldRetryRequest: Bool {
        switch self {
        case .timeout, .rateLimit:
            return true
        case .maxTimeouts, .maxRetriesError, .currentlyInARetryDelay, .invalidURL, .requestCancelled, .internetConnectionFailed, .urlRequestCreationFailure, .markdownNotFound, .other:
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
        case .urlRequestCreationFailure:
            return "Unable to create URL request."
        case .markdownNotFound:
            fatalErrorIfDebug()
            return "Markdown file not found"
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
    case secretsNotFound
    case nodeTypeNotSupported(String)
    case responseDecodingFailure(String)
    case portValueDescriptionNotSupported(String)
}

extension StitchAIManagerError: CustomStringConvertible {
    var description: String {
        switch self {
        case .contentDataDecodingError(let contentData, let errorResponse):
            return "Unable to parse OpenAI response data from: \(contentData) with error: \(errorResponse)"
        case .secretsNotFound:
            return "No secrets file found."
        case .nodeTypeNotSupported(let nodeType):
            return "No node type found for: \(nodeType)"
        case .responseDecodingFailure(let errorMessage):
            return "OpenAI respopnse decoding failed with the following error: \(errorMessage)"
        case .portValueDescriptionNotSupported(let nodeKindString):
            return "PortValue descriptions aren't supported for node kind: \(nodeKindString) due to PorValue version mismatch between the AI schema and SSK."
        }
    }
}

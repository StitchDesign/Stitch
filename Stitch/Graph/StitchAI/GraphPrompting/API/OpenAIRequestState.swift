//
//  OpenAIRequestState.swift
//  Stitch
//
//  Created by Nicholas Arner on 5/9/25.
//

import Foundation

public enum OpenAIRequestState: Equatable {
    case idle
    case makingRequest
    case parsingJSON
    case creatingGraphActions
    case buildingGraph
    case completed
    case failed(String)
    
    public var isInProgress: Bool {
        switch self {
        case .makingRequest, .parsingJSON, .creatingGraphActions, .buildingGraph:
            return true
        default:
            return false
        }
    }
    
    public var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .makingRequest:
            return "Making OpenAI Request"
        case .parsingJSON:
            return "Parsing JSON Response"
        case .creatingGraphActions:
            return "Creating Graph Actions"
        case .buildingGraph:
            return "Building Graph"
        case .completed:
            return "Completed"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
}

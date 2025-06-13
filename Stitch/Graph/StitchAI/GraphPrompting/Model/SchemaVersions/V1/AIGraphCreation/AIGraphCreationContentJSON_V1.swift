//
//  AIGraphCreationContentJSON_V1.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import StitchSchemaKit
import SwiftUI

enum AIGraphCreationContentJSON_V1: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V1
    typealias PreviousInstance = Self.AIGraphCreationContentJSON
    // MARK: - end
    
    /// Represents the structured content of a message
    struct AIGraphCreationContentJSON: Codable {
        var steps: [Step_V1.Step] // Array of steps in the visual programming sequence
    }
}

extension AIGraphCreationContentJSON_V1.AIGraphCreationContentJSON: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: AIGraphCreationContentJSON_V1.AIGraphCreationContentJSON) {
        fatalError()
    }
}

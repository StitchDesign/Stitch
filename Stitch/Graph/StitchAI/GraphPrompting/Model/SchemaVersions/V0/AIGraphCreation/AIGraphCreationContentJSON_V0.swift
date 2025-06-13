//
//  AIGraphCreationContentJSON_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import StitchSchemaKit
import SwiftUI

enum AIGraphCreationContentJSON_V0: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V0
    typealias PreviousInstance = Self.AIGraphCreationContentJSON
    // MARK: - end
    
    /// Represents the structured content of a message
    struct AIGraphCreationContentJSON: Codable {
        var steps: [Step_V0.Step] // Array of steps in the visual programming sequence
    }
}

extension AIGraphCreationContentJSON_V0.AIGraphCreationContentJSON: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: AIGraphCreationContentJSON_V0.AIGraphCreationContentJSON) {
        fatalError()
    }
}

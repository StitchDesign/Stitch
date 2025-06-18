//
//  JavaScriptNodeSettingsAI_V1.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum JavaScriptNodeSettingsAI_V1: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V1
    typealias PreviousInstance = Self.JavaScriptNodeSettingsAI
    // MARK: - end
    
    /// Redundant data structures needed for encoding node type for AI.
    struct JavaScriptNodeSettingsAI: Codable {
        var suggested_title: String
        var script: String
        var input_definitions: [JavaScriptPortDefinitionAI]
        var output_definitions: [JavaScriptPortDefinitionAI]
    }
}

extension JavaScriptNodeSettingsAI_V1.JavaScriptNodeSettingsAI: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: JavaScriptNodeSettingsAI_V1.JavaScriptNodeSettingsAI) {
        fatalError()
    }
}

//
//  JavaScriptPortDefinitionAI_V1.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum JavaScriptPortDefinitionAI_V1: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V1
    typealias NodeType = StitchAIPortValue_V1.NodeType
    typealias PreviousInstance = Self.JavaScriptPortDefinitionAI
    // MARK: - end
    
    struct JavaScriptPortDefinitionAI: Codable {
        var label: String
        var strict_type: NodeType
    }
}

extension JavaScriptPortDefinitionAI_V1.JavaScriptPortDefinitionAI: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: JavaScriptPortDefinitionAI_V1.JavaScriptPortDefinitionAI) {
        fatalError()
    }
}

extension JavaScriptPortDefinitionAI_V1.JavaScriptPortDefinitionAI {
    enum CodingKeys : String, CodingKey {
        case label
        case strict_type
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.label, forKey: .label)
        try container.encode(self.strict_type.asLLMStepNodeType, forKey: .strict_type)
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .strict_type)
        
        self.label = try container.decode(String.self, forKey: .label)
        guard let strictType = JavaScriptPortDefinitionAI_V1.NodeType(llmString: typeString) else {
            throw StitchAIManagerError.nodeTypeNotSupported(typeString)
        }
        
        self.strict_type = strictType
    }
}

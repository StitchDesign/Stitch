//
//  StitchAISchema.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/9/25.
//

import SwiftUI
import StitchSchemaKit

struct StitchAISchemaMeta: Encodable {
    let valueTypes: [StitchAISchemaNodeType]
}

extension StitchAISchemaMeta {
    static func createSchema() -> Self {
//        let valueTypes = StitchAINodeType.allCases.filter { $0 != .none }
        let valueTypes = StitchAINodeType.allCases.filter { $0 != .none && $0 != .scrollMode }
        let schema = StitchAISchemaMeta(valueTypes: valueTypes.map { .init(type: $0) })
        return schema
    }
}

struct StitchAISchemaNodeType {
    let type: StitchAINodeType
}

extension StitchAISchemaNodeType: Encodable {
    enum StitchSchemaTypeCodingKeys: String, CodingKey {
        case type
        case example
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StitchSchemaTypeCodingKeys.self)
        
        let defaultValue = self.type.defaultPortValue.anyCodable
        
        try container.encode(self.type.asLLMStepNodeType, forKey: .type)
        try container.encode(defaultValue, forKey: .example)
    }
}

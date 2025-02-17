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
        let valueTypes = NodeType.allCases.filter { $0 != .none }
        let schema = StitchAISchemaMeta(valueTypes: valueTypes.map { .init(type: $0) })
        return schema
    }
}

struct StitchAISchemaNodeType {
    let type: NodeType
}

extension StitchAISchemaNodeType: Encodable {
    enum StitchSchemaTypeCodingKeys: String, CodingKey {
        case type
        case example
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StitchSchemaTypeCodingKeys.self)
        
        let defaultValue = self.type.defaultPortValue.anyCodable
        
        try container.encode(self.type.display, forKey: .type)
        try container.encode(defaultValue, forKey: .example)
    }
}

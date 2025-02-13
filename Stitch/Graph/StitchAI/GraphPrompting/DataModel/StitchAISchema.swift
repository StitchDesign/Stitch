//
//  StitchAISchema.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/9/25.
//

import SwiftUI
import StitchSchemaKit

struct StitchAISchemaMeta: Encodable {
    let nodeTypes: [StitchAISchemaNodeType]
}

extension StitchAISchemaMeta {
    static func createSchema() -> Self {
        let nodeTypes = NodeType.allCases.filter { $0 != .none }
        let schema = StitchAISchemaMeta(nodeTypes: nodeTypes.map { .init(type: $0) })
        return schema
    }
}

struct StitchAISchemaNodeType {
    let type: NodeType
}

extension StitchAISchemaNodeType: Encodable {
    enum StitchSchemaTypeCodingKeys: String, CodingKey {
        case type
        //    case properties
        case example
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StitchSchemaTypeCodingKeys.self)
        
        let defaultValue = self.type.defaultPortValue.anyCodable
        
//        let mirror = Mirror(reflecting: defaultValue)
//        let properties = mirror.children.map { $0.label }
        
        try container.encode(self.type.display, forKey: .type)
//        try container.encode(properties, forKey: .properties)
        
        // TODO: come back and consider making everything case iterable
        //        let defaultValueType = self.type.portValueTypeForStitchAI
//        if let caseIterable = defaultValueType as? (any CaseIterable & Encodable) {
//            try container.encode(caseIterable.allCases , forKey: .examples)
//        }
        
        try container.encode(defaultValue, forKey: .example)
    }
}

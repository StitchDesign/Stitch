//
//  NodeType_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import StitchSchemaKit

// MARK: update at cadence when Stitch AI utils update node type
extension StitchAIPortValue_V0.NodeType {
    init(llmString: String) throws {
        guard let match = StitchAIPortValue_V0.NodeType.allCases.first(where: {
            $0.asLLMStepNodeType == llmString.toCamelCase()
        }) else {
            throw StitchAIParsingError.nodeTypeParsing(llmString)
        }
        
        self = match
    }
    
    // TODO: our OpenAI schema does not define all possible node-types, and those node types that we do define use camelCase
    // TODO: some node types use human-readable strings ("Sizing Scenario"), not camelCase ("sizingScenario") as their raw value; so can't use `NodeType(rawValue:)` constructor
    var asLLMStepNodeType: String {
        self.display.toCamelCase()
    }
}

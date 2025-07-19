//
//  StitchAIRequestBuilder_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/19/25.
//

import SwiftUI

enum StitchAIRequestBuilder_V0 {
    enum StitchAIRequestBuilderFunctions: String, CaseIterable {
        case codeBuilder = "create_swiftui_code"
        case codeEditor = "edit_swiftui_code"
        case patchBuilder = "patch_builder"
    }
}

extension StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions {
    static let allFunctions: [OpenAIFunction] = Self.allCases.map(\.function)
    
    var function: OpenAIFunction {
        switch self {
        case .codeBuilder:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Generate SwiftUI code from Stitch concepts.",
                parameters: OpenAISchema(
                    type: .object,
                    properties: StitchAIRequestBuilder_V0.SourceCodeResponseSchema(),
                    required: ["source_code"],
                    description: "SwiftUI source code."),
                strict: true
            )
        
        case .codeEditor:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Edit SwiftUI code based on user prompt.",
                parameters: OpenAISchema(
                    type: .object,
                    properties: StitchAIRequestBuilder_V0.SourceCodeResponseSchema(),
                    required: ["source_code"],
                    description: "SwiftUI source code."),
                strict: true
            )
            
        case .patchBuilder:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Build Stitch graphs based on layer data and SwiftUI source code.",
                parameters: OpenAISchema(
                    type: .object,
                    properties: AIPatchBuilderResponseFormat_V0.GraphBuilderSchema(),
                    required: ["javascript_patches", "native_patches", "native_patch_value_type_settings", "patch_connections", "layer_connections", "custom_patch_input_values"],
                    description: "Patch data for a Stitch graph."),
                strict: true
            )
        }
    }
}

extension StitchAIRequestBuilder_V0 {
    struct SourceCodeResponseSchema: Encodable {
        let source_code = OpenAISchema(
            type: .string,
            description: "SwiftUI source code.")
    }
    
    struct SourceCodeResponse: Codable {
        let source_code: String
    }
}

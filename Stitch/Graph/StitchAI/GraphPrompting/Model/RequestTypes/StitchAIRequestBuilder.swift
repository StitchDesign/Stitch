//
//  StitchAIRequestBuilder.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/19/25.
//

import SwiftUI

struct StitchAIRequestBuilder_V0 {
    struct SourceCodeResponseSchema: Encodable {
        let source_code = OpenAISchema(
            type: .string,
            description: "SwiftUI source code.")
    }
    
    struct SourceCodeResponse: Codable {
        let source_code: String
    }
}

extension StitchAIRequestBuilder_V0 {
    enum StitchAIRequestType {
        case userPrompt
        case imagePrompt
    }
    
    enum StitchAIRequestBuilderFunction: String {
        case codeBuilder = "create_swiftui_code"
        case codeBuilderFromImage = "create_code_from_image"
        case codeEditor = "edit_swiftui_code"
        case patchBuilder = "patch_builder"
    }
}


extension StitchAIRequestBuilder_V0.StitchAIRequestType {
    var allFunctions: [StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction] {
        switch self {
        case .userPrompt:
            return [.codeBuilder, .codeEditor, .patchBuilder]
        case .imagePrompt:
            return [.codeBuilderFromImage, .patchBuilder]
        }
    }
    
    var allOpenAIFunctions: [OpenAIFunction] {
        self.allFunctions.map(\.function)
    }
    
    var goalDescription: String {
        switch self {
        case .userPrompt:
            return """
                The end-goal is to produce structured data that modifies an existing document. To get there, we will first convert existing graph data into SwiftUI code, make modifications to that SwiftUI code based on user prompt, and then convert that data back into Stitch graph data.
                """
        case .imagePrompt:
            return """
                The end-goal is to produce structured data that creates prototype data from an uploaded image. To get there, we will first create SwiftUI code that produces a view matching the image, and then convert the source code into Stitch graph data.
                """
        }
    }
    
    var listedFunctionsDescriptionForSystemPrompt: String {
        self.allFunctions.enumerated().map { index, fn in
            """
            \(index + 1). \(fn.rawValue): \(fn.functionDescription)
            """
        }.joined(separator: "\n")
    }
}

extension StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction {
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
            
        case .codeBuilderFromImage:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Generate SwiftUI code from an image.",
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
    
    var functionDescription: String {
        switch self {
        case .codeBuilder:
            return """
                **Builds SwiftUI Code from Stitch Data.** You will receive as input structured data about the current Stitch document, and your output must be a SwiftUI app that reflects this prototype.
                """
        case .codeBuilderFromImage:
            return """
                **Builds SwiftUI Code from an Image.** You will receive as input an uploaded image, and your output must be a SwiftUI app that attempts to replicate the uploaded image.
                """
        case .codeEditor:
            return """
                **Edits SwiftUI Code.** Based on the SwiftUI source code created from the last step, modify the code based on the user prompt.
                """
        case .patchBuilder:
            return """
                **Creates Stitch structured prototype data.** Convert the SwiftUI source code into Stitch concepts. 
                """
        }
    }
}

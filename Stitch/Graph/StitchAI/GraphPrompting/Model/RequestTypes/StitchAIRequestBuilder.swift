//
//  StitchAIRequestBuilder.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/19/25.
//

import SwiftUI

struct StitchAIRequestBuilder_V0 {
    struct ImageRequestInputParameters: Encodable {
        let user_prompt = OpenAISchema(type: .string)
        let image_data = OpenAISchema(type: .object,
                                      properties: ImageDataSchema(),
                                      required: ["type", "image_url", "detail"])
    }
    
    struct EditRequestInputParameters: Encodable {
        let user_prompt = OpenAISchema(
            type: .string,
            description: "Code change request by the user.")
        
        let source_code = OpenAISchema(
            type: .string,
            description: "SwiftUI source code.")
    }
    
    struct SourceCodeResponseSchema: Encodable {
        let source_code = OpenAISchema(
            type: .string,
            description: "SwiftUI source code.")
    }
    
    struct ImageDataSchema: Encodable {
        let type = OpenAISchema(type: .string)
        let image_url = OpenAISchema(type: .string)
        let detail = OpenAISchema(type: .string)
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
        case processCode = "process_code"
        case processPatchData = "process_patch_data"
    }
}


extension StitchAIRequestBuilder_V0.StitchAIRequestType {
    var allFunctions: [StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunction] {
        switch self {
        case .userPrompt:
            return [.codeBuilder, .codeEditor, .processCode, .patchBuilder, .processPatchData]
        case .imagePrompt:
            return [.codeBuilderFromImage, .processCode, .patchBuilder, .processPatchData]
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
            \(index + 1). `\(fn.rawValue)`: \(fn.functionDescription)
            """
        }.joined(separator: "\n")
    }
    
    var systemPromptTitle: String {
        switch self {
        case .userPrompt:
            return "SwiftUI Code Builder from Stitch Graph Data"
        case .imagePrompt:
            return "SwiftUI Code Builder from Image Upload"
        }
    }
    
    var inputTypeDescription: String {
        switch self {
        case .userPrompt:
            return "existing graph data"
        case .imagePrompt:
            return "image upload"
        }
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
                    properties: AIGraphData_V0.GraphDataSchema(),
                    required: ["layer_data_list", "patch_data"],
                    description: "Graph data of existing graph."),
                strict: true
            )
            
        case .codeBuilderFromImage:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Generate SwiftUI code from an image.",
                parameters: OpenAISchema(
                    type: .object,
                    properties: StitchAIRequestBuilder_V0.ImageRequestInputParameters(),
                    required: ["user_prompt", "image_data"],
                    description: "Parameters for building SwiftUI view from image."),
                strict: true
            )
        
        case .codeEditor:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Edit SwiftUI code based on user prompt.",
                parameters: OpenAISchema(
                    type: .object,
                    properties: StitchAIRequestBuilder_V0.EditRequestInputParameters(),
                    required: ["user_prompt", "source_code"],
                    description: "SwiftUI source code of existing graph."),
                strict: true
            )
            
        case .processCode:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Processes some SwiftUI code before Stitch conversion.",
                parameters: OpenAISchema(
                    type: .object,
                    properties: StitchAIRequestBuilder_V0.SourceCodeResponseSchema(),
                    required: ["source_code"],
                    description: "SwiftUI source code following user request."),
                strict: true
            )
            
        case .patchBuilder:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Build Stitch graphs based on layer data and SwiftUI source code.",
                parameters: OpenAISchema(
                    type: .object,
                    properties: AIPatchBuilderFunctionInputsSchema(),
                    required: ["swiftui_source_code", "layer_data_list"],
                    description: "Provides SwiftUI source code and Stitch layer data for a function that produces Stitch patch data."),
                strict: true
            )
            
        case .processPatchData:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Processes patch graph data.",
                parameters: AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.PatchData,
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
        case .processCode:
            return """
                **Processes SwiftUI source code.** Let's Stitch process code for deriving some data before sending into patch builder.
                """
        
        case .patchBuilder:
            return """
                **Creates Stitch structured prototype data.** Convert the SwiftUI source code into Stitch concepts. 
                """
            
        case .processPatchData:
            return """
                **Processes patch graph data.** Last step before patch data is combined with already parsed layer data to update a Stitch document.
                """
        }
    }
    
    func getAssistantPrompt(for requestType: StitchAIRequestBuilder_V0.StitchAIRequestType) throws -> String? {
        switch self {
        case .codeBuilder:
            return try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: requestType)
            
        case .codeBuilderFromImage:
            return try StitchAIManager.aiCodeGenSystemPromptGenerator(requestType: requestType)
            
        case .codeEditor:
            return try StitchAIManager.aiCodeEditSystemPromptGenerator(requestType: requestType)
            
        case .processCode:
            // End of function calling, no more subsequent calls to make
            return nil
            
        case .patchBuilder:
            return try StitchAIManager.aiPatchBuilderSystemPromptGenerator()
            
        case .processPatchData:
            // End of function calling, no more subsequent calls to make
            return nil
        }
    }
}

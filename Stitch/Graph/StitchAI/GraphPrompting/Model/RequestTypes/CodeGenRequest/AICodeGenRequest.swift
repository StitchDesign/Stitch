//
//  AICodeGenRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

// fka `AICodeGenFromGraphRequest`
struct AICodeGenWithImageRequest: StitchAICodeCreator {
    static let type = StitchAIRequestBuilder_V0.StitchAIRequestType.userPrompt
    
    let id: UUID
    let userPrompt: String
    let swiftUICodeOfGraph: String
    let base64Image: String?
    
    @MainActor
    init(prompt: String,
         swiftUICodeOfGraph: String,
         base64Image: String? = nil) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        self.userPrompt = prompt
        self.swiftUICodeOfGraph = swiftUICodeOfGraph
        self.base64Image = base64Image
    }
    
    @MainActor
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager,
                    dataGlossaryPrompt: String) async throws -> String {
        log("AICodeGenWithImageRequest.createCode initial code:\n\(self.swiftUICodeOfGraph)")
        
        let editInputs = StitchAIRequestBuilder_V0.EditCodeParams(
            source_code: swiftUICodeOfGraph,
            user_prompt: userPrompt)
        
        // If we have an image, use the vision request; otherwise use the regular request
        if let imageData = base64Image {
            // Validate parameters for the selected model
            let selectedModel = document.openaiModel.asOpenAIModel
            let validatedVerbosity = OpenAIModelConstraints.validateVerbosity(for: selectedModel, requestedVerbosity: document.openaiVerbosity)
            let validatedReasoningEffort = OpenAIModelConstraints.validateReasoningEffort(for: selectedModel, requestedEffort: document.openaiReasoningEffort)
            
            // Debug print OpenAI configuration
            log("🤖 Vision Request - Model: \(document.openaiModel), Verbosity: \(validatedVerbosity) (requested: \(document.openaiVerbosity)), Reasoning Effort: \(validatedReasoningEffort) (requested: \(document.openaiReasoningEffort))")
            
            // Request for code edit with image
            let visionEditRequest = try OpenAIVisionChatCompletionRequest(
                id: self.id,
                requestType: Self.type,
                dataGlossaryPrompt: dataGlossaryPrompt,
                assistantPrompt: try StitchAIManager.aiCodeEditSystemPromptGenerator(requestType: Self.type),
                textInput: try editInputs.encodeToString(),
                base64Image: imageData,
                model: document.openaiModel,
                verbosity: validatedVerbosity,
                reasoningEffort: validatedReasoningEffort,
                willStream: false)
            
            let codeEditResult = try await visionEditRequest
                .request(document: document,
                         aiManager: aiManager)
            
            return codeEditResult
        } else {
            // Validate parameters for the selected model
            let selectedModel = document.openaiModel.asOpenAIModel
            let validatedVerbosity = OpenAIModelConstraints.validateVerbosity(for: selectedModel, requestedVerbosity: document.openaiVerbosity)
            let validatedReasoningEffort = OpenAIModelConstraints.validateReasoningEffort(for: selectedModel, requestedEffort: document.openaiReasoningEffort)
            
            // Debug print OpenAI configuration
            log("🤖 Regular Request - Model: \(document.openaiModel), Verbosity: \(validatedVerbosity) (requested: \(document.openaiVerbosity)), Reasoning Effort: \(validatedReasoningEffort) (requested: \(document.openaiReasoningEffort))")
            
            // Fallback to regular text-only request
            let codeEditRequest = try OpenAIChatCompletionRequest(
                id: self.id,
                requestType: Self.type,
                dataGlossaryPrompt: dataGlossaryPrompt,
                assistantPrompt: try StitchAIManager.aiCodeEditSystemPromptGenerator(requestType: Self.type),
                inputs: editInputs,
                model: document.openaiModel,
                verbosity: validatedVerbosity,
                reasoningEffort: validatedReasoningEffort)
            
            let codeEditResult = try await codeEditRequest
                .request(document: document,
                         aiManager: aiManager)
            
            return codeEditResult
        }
    }
}

extension StitchAICodeCreator {
    @MainActor
    func getRequestTask(userPrompt: String,
                        document: StitchDocumentViewModel) throws -> Task<Result<AIGraphData_V0.GraphData, any Error>, Never> {
        log("getRequestTask: user prompt: \(userPrompt)")
        
        let dataGlossaryPrompt = try StitchAIManager
            .stitchAIDataGlossarySystemPrompt(graph: document.visibleGraph)
        let request = self
        
        return Task(priority: .high) { [weak document] in
            guard let document = document,
                  let aiManager = document.aiManager else {
                log("getRequestTask: AICodeGenRequest: getRequestTask: no document or ai manager", .logToServer)
                
                if let document: StitchDocumentViewModel = document {
                    return .failure(StitchStore.displayError(failure: StitchAIManagerError.secretsNotFound,
                                                             document: document))
                } else {
                    return .failure(StitchAIManagerError.secretsNotFound)
                }
            }
            
            do {
                let actionsResult = try await request
                    .processRequest(userPrompt: userPrompt,
                                    document: document,
                                    aiManager: aiManager,
                                    dataGlossaryPrompt: dataGlossaryPrompt)
                
                let graphData = actionsResult.graphData
                let allDiscoveredErrors = actionsResult.caughtErrors
                
                logToServerIfRelease("SUCCESS Patch Builder:\n\((try? graphData.encodeToPrintableString()) ?? "")")
                
                DispatchQueue.main.async { [weak document] in
                    guard let document = document else { return }
                    
                    do {
                        Task(priority: .high) {
                            try await graphData
                                .applyAIGraph(to: document,
                                              viewStatePatchConnections: actionsResult.graphData .viewStatePatchConnections,
                                              requestType: Self.type)
                        }
                        
#if STITCH_AI_TESTING || DEBUG || DEV_DEBUG
                        // Display parsing warnings
                        if !allDiscoveredErrors.isEmpty {
                            let caughtErrorsString = allDiscoveredErrors.reduce(into: "") { stringBuilder, error in
                                stringBuilder += "\n\(error)"
                            }
                            
                            document.storeDelegate?.alertState.stitchFileError = .unknownError("Warnings for the following unknown concepts:\(caughtErrorsString)")
                        }
#endif
                        
                    } catch {
                        logToServerIfRelease("Error applying AI graph: \(error.localizedDescription)")
                        document.storeDelegate?.alertState.stitchFileError = .unknownError("\(error)")
                    }
                    
                    document.aiManager?.currentTaskTesting = nil
                    document.insertNodeMenuState.show = false
                }
                
                return .success(graphData)
            } catch {
                return .failure(StitchStore.displayError(failure: error,
                                                         document: document))
            }
        }
    }

    private func processRequest(userPrompt: String,
                                document: StitchDocumentViewModel,
                                aiManager: StitchAIManager,
                                dataGlossaryPrompt: String) async throws -> SwiftSyntaxActionsResult {
        logToServerIfRelease("SUCCESS: userPrompt: \(userPrompt)")
        
        let swiftUICode = try await self
            .createCode(document: document,
                        aiManager: aiManager,
                        dataGlossaryPrompt: dataGlossaryPrompt)

//        let swiftUICode = """
//            struct ContentView: View {
//                var body: some View {
//                    VStack(spacing: 32) {
//                        Text(PortValueDescription(value: "1 (234) 567-8900", value_type: "string"))
//                            .layerId("22222222-2222-2222-2222-222222222222")
//                        Text(PortValueDescription(value: "Add Number", value_type: "string"))
//                            .foregroundColor([PortValueDescription(value: "#007AFFFF", value_type: "color")])
//                            .layerId("33333333-3333-3333-3333-333333333333")
//                        VStack(spacing: 24) {
//                            HStack(spacing: 24) {
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-000000000001")
//                                    VStack(spacing: 0) {
//                                        Text(PortValueDescription(value: "1", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000000A")
//                                        Text(PortValueDescription(value: "", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000000B")
//                                    }
//                                    .layerId("51000000-0000-0000-0000-00000000000C")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-000000000002")
//                                    VStack(spacing: 0) {
//                                        Text(PortValueDescription(value: "2", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000001A")
//                                        Text(PortValueDescription(value: "ABC", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000001B")
//                                    }
//                                    .layerId("51000000-0000-0000-0000-00000000001C")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-000000000003")
//                                    VStack(spacing: 0) {
//                                        Text(PortValueDescription(value: "3", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000002A")
//                                        Text(PortValueDescription(value: "DEF", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000002B")
//                                    }
//                                    .layerId("51000000-0000-0000-0000-00000000002C")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                            }
//                            HStack(spacing: 24) {
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-000000000004")
//                                    VStack(spacing: 0) {
//                                        Text(PortValueDescription(value: "4", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000003A")
//                                        Text(PortValueDescription(value: "GHI", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000003B")
//                                    }
//                                    .layerId("51000000-0000-0000-0000-00000000003C")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-000000000005")
//                                    VStack(spacing: 0) {
//                                        Text(PortValueDescription(value: "5", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000004A")
//                                        Text(PortValueDescription(value: "JKL", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000004B")
//                                    }
//                                    .layerId("51000000-0000-0000-0000-00000000004C")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-000000000006")
//                                    VStack(spacing: 0) {
//                                        Text(PortValueDescription(value: "6", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000005A")
//                                        Text(PortValueDescription(value: "MNO", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000005B")
//                                    }
//                                    .layerId("51000000-0000-0000-0000-00000000005C")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                            }
//                            HStack(spacing: 24) {
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-000000000007")
//                                    VStack(spacing: 0) {
//                                        Text(PortValueDescription(value: "7", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000006A")
//                                        Text(PortValueDescription(value: "PQRS", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000006B")
//                                    }
//                                    .layerId("51000000-0000-0000-0000-00000000006C")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-000000000008")
//                                    VStack(spacing: 0) {
//                                        Text(PortValueDescription(value: "8", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000007A")
//                                        Text(PortValueDescription(value: "TUV", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000007B")
//                                    }
//                                    .layerId("51000000-0000-0000-0000-00000000007C")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-000000000009")
//                                    VStack(spacing: 0) {
//                                        Text(PortValueDescription(value: "9", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000008A")
//                                        Text(PortValueDescription(value: "WXYZ", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-00000000008B")
//                                    }
//                                    .layerId("51000000-0000-0000-0000-00000000008C")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                            }
//                            HStack(spacing: 24) {
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-00000000000A")
//                                    Text(PortValueDescription(value: "*", value_type: "string"))
//                                        .layerId("51000000-0000-0000-0000-00000000009A")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-00000000000B")
//                                    VStack(spacing: 0) {
//                                        Text(PortValueDescription(value: "0", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-0000000000AA")
//                                        Text(PortValueDescription(value: "+", value_type: "string"))
//                                            .layerId("51000000-0000-0000-0000-0000000000AB")
//                                    }
//                                    .layerId("51000000-0000-0000-0000-0000000000AC")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                                ZStack {
//                                    Circle()
//                                        .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                        .layerId("51000000-0000-0000-0000-00000000000C")
//                                    Text(PortValueDescription(value: "#", value_type: "string"))
//                                        .layerId("51000000-0000-0000-0000-0000000000BA")
//                                }
//                                .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])
//                            }
//                        }
//                        .layerId("44444444-4444-4444-4444-444444444444")
//                        HStack(spacing: 100) {
//                            Circle()
//                                .fill([PortValueDescription(value: "#FFFFFF00", value_type: "color")])
//                                .frame([PortValueDescription(value: ["height":"64.0","width":"64.0"], value_type: "size")])
//                                .layerId("blank0000-0000-0000-0000-000000000000")
//                            ZStack {
//                                Circle()
//                                    .fill([PortValueDescription(value: "#FF9500FF", value_type: "color")])
//                                    .layerId("60000000-0000-0000-0000-000000000000")
//                                Text(PortValueDescription(value: "📞", value_type: "string"))
//                                    .layerId("60000000-0000-0000-0000-00000000000A")
//                            }
//                            .frame([PortValueDescription(value: ["height":"64.0","width":"64.0"], value_type: "size")])
//                            ZStack {
//                                Circle()
//                                    .fill([PortValueDescription(value: "#E5E5E5FF", value_type: "color")])
//                                    .layerId("70000000-0000-0000-0000-000000000000")
//                                Text(PortValueDescription(value: "×", value_type: "string"))
//                                    .layerId("70000000-0000-0000-0000-00000000000A")
//                            }
//                            .frame([PortValueDescription(value: ["height":"64.0","width":"64.0"], value_type: "size")])
//                        }
//                        .layerId("55555555-5555-5555-5555-555555555555")
//                    }
//                    .padding()
//                    .layerId("11111111-1111-1111-1111-111111111111")
//                }
//
//                func updateLayerInputs() {
//                }
//            }
//
//            """
        
        logToServerIfRelease("StitchAICodeCreator swiftUICode:\n\(swiftUICode)")
        
//        guard let parsedVarBody = VarBodyParser.extract(from: swiftUICode) else {
//            logToServerIfRelease("SwiftUISyntaxError.couldNotParseVarBody.localizedDescription: \(SwiftUISyntaxError.couldNotParseVarBody.localizedDescription)")
//            throw SwiftUISyntaxError.couldNotParseVarBody
//        }
        
//        logToServerIfRelease("parsedVarBody:\n\(parsedVarBody)")
        

        let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(swiftUICode,
                                                                   varNameIdMap: [:])
        
        logToServerIfRelease("StitchAICodeCreator codeParserResult:\n\(codeParserResult)")
        
        let actionsResult = try codeParserResult.deriveStitchActions()
        
        print("Derived Stitch layer data:\n\((try? actionsResult.encodeToPrintableString()) ?? "")")
        
        return actionsResult
    }
}

extension StitchStore {
    @MainActor
    static func displayError(failure: any Error,
                             document: StitchDocumentViewModel) -> any Error {
        log("AICodeGenRequest: getRequestTask: request.request: failure: \(failure.localizedDescription)", .logToServer)
        print(failure.localizedDescription)
        document.aiManager?.currentTaskTesting = nil
        document.insertNodeMenuState.show = false
        
        // Display error
        document.storeDelegate?.alertState.stitchFileError = .unknownError("\(failure)")
        return failure
    }
}

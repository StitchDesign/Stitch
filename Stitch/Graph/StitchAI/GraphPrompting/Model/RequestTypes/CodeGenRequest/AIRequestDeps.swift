//
//  AIRequestDeps.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

/*
 Some of the dependencies needed to make a request:
 - the user's prompt
 - SwiftUI code of the existing graph
 - any image the user uploaded
 */
// fka `AICodeGenRequest`
// fka `AICodeGenFromGraphRequest`
// fka `AICodeGenWithImageRequest`
struct AIRequestDeps: StitchAICodeCreator {
    
    let id: UUID
    let aiProvider: AIProvider
    let userPrompt: String
    let swiftUICodeOfGraph: String
    let base64Image: String?
    
    @MainActor
    init(prompt: String,
         aiProvider: AIProvider,
         swiftUICodeOfGraph: String,
         base64Image: String? = nil) {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        self.aiProvider = aiProvider
        self.userPrompt = prompt
        self.swiftUICodeOfGraph = swiftUICodeOfGraph
        self.base64Image = base64Image
    }
    
    @MainActor
    func createCode(document: StitchDocumentViewModel,
                    aiManager: StitchAIManager) async throws -> String {
        log("AIRequestDeps.createCode initial code:\n\(self.swiftUICodeOfGraph)")
        
        guard let secrets = try? Secrets() else {
            log("AIRequestDeps.createCode: No secrets found")
            throw StitchAIManagerError.secretsNotFound
        }
        
        let editInputs = StitchAIRequestBuilder_V0.EditCodeParams(
            source_code: swiftUICodeOfGraph,
            user_prompt: userPrompt)
        
        // Determine which model to use based on current provider
        let model: AIModel = switch aiProvider {
        case .openAI: 
            .openAI(document.openaiModel.asOpenAIModel)
        case .claude: 
            .claude(document.claudeModel.asClaudeModel)
        }
        
        let validatedVerbosity = switch model {
        case .openAI(let openAIModel):
            OpenAIModelConstraints.validateVerbosity(for: openAIModel, requestedVerbosity: document.openaiVerbosity)
        case .claude:
            OpenAIVerbosity.medium // Claude doesn't use verbosity but we need to pass something
        }
        
        // Debug print configuration
        log("🤖 AI Request - Model: \(model.displayName), Verbosity: \(validatedVerbosity) (requested: \(document.openaiVerbosity)), Reasoning Effort: \(document.openaiReasoningEffort)")
        
        // Prepare request parameters
        let previewWindowPrompt = StitchAIManager.previewWindowInfoPromptGenerator(
            previewWindowSize: document.previewWindowSize,
            previewWindowBackgroundColor: document.previewWindowBackgroundColor
        )
        let userPrompt = try editInputs.encodeToString()

        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Use provider-agnostic orchestrator
        let codeEditResult = try await makeAIRequest(
            previewWindowPrompt: previewWindowPrompt,
            userPrompt: userPrompt,
            base64Image: base64Image,
            openAIAPIKey: secrets.openAIAPIKey,
            model: model,
            verbosity: validatedVerbosity,
            reasoningEffort: document.openaiReasoningEffort.asOpenAIReasoningEffort,
            document: document
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        log("⏱️ AI Request completed in \(String(format: "%.2f", duration)) seconds using \(model.displayName)")
        
        return codeEditResult
    }
}

extension StitchAICodeCreator {
    @MainActor
    func getRequestTask(userPrompt: String,
                        document: StitchDocumentViewModel) throws -> Task<Result<AIGraphData_V0.GraphData, any Error>, Never> {
        log("getRequestTask: user prompt: \(userPrompt)")
        
        let request = self
        
        return Task(priority: .high) { [weak document] in
            guard let document = document,
                  let aiManager = document.aiManager else {
                // log("getRequestTask: AICodeGenRequest: getRequestTask: no document or ai manager", .logToServer)
                
                if let document: StitchDocumentViewModel = document {
                    return .failure(StitchStore.displayError(failure: StitchAIManagerError.secretsNotFound,
                                                             document: document))
                } else {
                    return .failure(StitchAIManagerError.secretsNotFound)
                }
            }
            
            do {
                var actionsResult = try await request
                    .processRequest(userPrompt: userPrompt,
                                    document: document,
                                    aiManager: aiManager)
                
                // logToServerIfRelease("SUCCESS Patch Builder:\n\((try? actionsResult.graphData.encodeToPrintableString()) ?? "")")
                
                DispatchQueue.main.async { [weak document] in
                    guard let document = document else { return }
                    
                    Task(priority: .high) {
                        await actionsResult
                            .applyAIGraph(to: document,
                                          viewStatePatchConnections: actionsResult.graphData.viewStatePatchConnections)
                    }
                    
                    // Note: task clearing and menu hiding are handled by resetStreamingUIState() called by AI providers
                }
                
                return .success(actionsResult.graphData)
            } catch let error as URLError where error.code == .cancelled {
                log("❌ AI request cancelled by user")
                
                // User cancelled request, silent error
                return .failure(SwiftUISyntaxError.userCancelledRequest)
            } catch {
                return .failure(StitchStore.displayError(failure: error,
                                                         document: document))
            }
        }
    }

    @MainActor
    func processRequest(userPrompt: String,
                        document: StitchDocumentViewModel,
                        aiManager: StitchAIManager) async throws -> SwiftSyntaxActionsResult {

        log("SUCCESS: userPrompt: \(userPrompt)")
        
//        let swiftUICode = try await self
//            .createCode(document: document,
//                        aiManager: aiManager)
        
        let swiftUICode = """
            struct ContentView: View {
                @State var position_1_1C35A642_DA8D_4965_9CA8_8B87750DA00B: [PortValueDescription] = []
                @State var layer_1C35A642_DA8D_4965_9CA8_8B87750DA00B_position: [PortValueDescription] = []
                @State var position_0_1C35A642_DA8D_4965_9CA8_8B87750DA00B: [PortValueDescription] = []
                @State var zIndex_1C35A642_DA8D_4965_9CA8_8B87750DA00B: [PortValueDescription] = []
                @State var color_1C35A642_DA8D_4965_9CA8_8B87750DA00B: [PortValueDescription] = []
                @State var tapPulse_1C35A642_DA8D_4965_9CA8_8B87750DA00B: [PortValueDescription] = []

            var body: some View {
                    ScrollView(showsIndicators: nil) {
                        Rectangle()
                            .fill(color_1C35A642_DA8D_4965_9CA8_8B87750DA00B)
                            .offset(position_0_1C35A642_DA8D_4965_9CA8_8B87750DA00B, position_1_1C35A642_DA8D_4965_9CA8_8B87750DA00B)
                            .frame([PortValueDescription(value: ["height":"50.0","width":"200.0"], value_type: "size")])
                            .zIndex(zIndex_1C35A642_DA8D_4965_9CA8_8B87750DA00B)
                            .simultaneousGesture(DragGesture().onChanged { g in
                                layer_1C35A642_DA8D_4965_9CA8_8B87750DA00B_position = [PortValueDescription(value: g.position, value_type: "position")]
                            })
                            .onTapGesture {
                                tapPulse_1C35A642_DA8D_4965_9CA8_8B87750DA00B = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                            }
                    }
                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

            }

            func updateLayerInputs() {
                let unpack_91BE30CD_CA1A_4F5C_9053_A2F01CFFF54C = NATIVE_STITCH_PATCH_FUNCTIONS["unpack || Patch"]([
                        layer_1C35A642_DA8D_4965_9CA8_8B87750DA00B_position
                    ])
                let loop_A960977C_E4A5_4640_B945_5DE108A6264E = NATIVE_STITCH_PATCH_FUNCTIONS["loop || Patch"]([
                        [PortValueDescription(value: 100, value_type: "number")]
                    ])
                let random_56081C23_7640_445A_A897_91BBC83ABB29 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
                        loop_A960977C_E4A5_4640_B945_5DE108A6264E[0],
                        [PortValueDescription(value: 0, value_type: "number")],
                        [PortValueDescription(value: 1, value_type: "number")]
                    ])
                let random_7C773470_810C_4E5D_BCE1_7C0D14FD22AF = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
                        loop_A960977C_E4A5_4640_B945_5DE108A6264E[0],
                        [PortValueDescription(value: 0, value_type: "number")],
                        [PortValueDescription(value: 1, value_type: "number")]
                    ])
                let random_86A3CD65_73E1_41E0_BE55_D2CD8EF4498A = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
                        loop_A960977C_E4A5_4640_B945_5DE108A6264E[0],
                        [PortValueDescription(value: 0, value_type: "number")],
                        [PortValueDescription(value: 1, value_type: "number")]
                    ])
                let rgbColor_0F41F852_B7A2_4524_B019_6BE9748EF1BD = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([
                        random_56081C23_7640_445A_A897_91BBC83ABB29[0],
                        random_7C773470_810C_4E5D_BCE1_7C0D14FD22AF[0],
                        random_86A3CD65_73E1_41E0_BE55_D2CD8EF4498A[0],
                        [PortValueDescription(value: 1, value_type: "number")]
                    ])
                let random_tapR_2A1B3C4D_5E6F_7890_ABCD_EF1234567890 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
                        tapPulse_1C35A642_DA8D_4965_9CA8_8B87750DA00B,
                        [PortValueDescription(value: 0, value_type: "number")],
                        [PortValueDescription(value: 1, value_type: "number")]
                    ])
                let random_tapG_3B2C4D5E_6F78_9012_CDEF_123456789ABC = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
                        tapPulse_1C35A642_DA8D_4965_9CA8_8B87750DA00B,
                        [PortValueDescription(value: 0, value_type: "number")],
                        [PortValueDescription(value: 1, value_type: "number")]
                    ])
                let random_tapB_4C3D5E6F_7890_1234_ABCD_EF123456789A = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
                        tapPulse_1C35A642_DA8D_4965_9CA8_8B87750DA00B,
                        [PortValueDescription(value: 0, value_type: "number")],
                        [PortValueDescription(value: 1, value_type: "number")]
                    ])
                let rgbColor_tap_5D4E6F70_8901_2345_BCDE_F123456789AB = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([
                        random_tapR_2A1B3C4D_5E6F_7890_ABCD_EF1234567890[0],
                        random_tapG_3B2C4D5E_6F78_9012_CDEF_123456789ABC[0],
                        random_tapB_4C3D5E6F_7890_1234_ABCD_EF123456789A[0],
                        [PortValueDescription(value: 1, value_type: "number")]
                    ])
                let optionPicker_colorChange_6E5F7081_9012_3456_CDEF_123456789ABC = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        tapPulse_1C35A642_DA8D_4965_9CA8_8B87750DA00B,
                        rgbColor_0F41F852_B7A2_4524_B019_6BE9748EF1BD[0],
                        rgbColor_tap_5D4E6F70_8901_2345_BCDE_F123456789AB[0]
                    ])
                position_0_1C35A642_DA8D_4965_9CA8_8B87750DA00B = unpack_91BE30CD_CA1A_4F5C_9053_A2F01CFFF54C[0]
                zIndex_1C35A642_DA8D_4965_9CA8_8B87750DA00B = loop_A960977C_E4A5_4640_B945_5DE108A6264E[0]
                color_1C35A642_DA8D_4965_9CA8_8B87750DA00B = optionPicker_colorChange_6E5F7081_9012_3456_CDEF_123456789ABC[0]
                position_1_1C35A642_DA8D_4965_9CA8_8B87750DA00B = unpack_91BE30CD_CA1A_4F5C_9053_A2F01CFFF54C[1]
            }


            }
            """

        log("userPrompt: \(userPrompt)") // Very helpful to see user-prompt here again
        log("StitchAICodeCreator swiftUICode:\n\(swiftUICode)")

        // Check if the AI returned empty code
        if swiftUICode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            log("ERROR: AI returned empty code for prompt: \(userPrompt)")
            throw StitchAIManagerError.emptyAIResponse
        }

        let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(swiftUICode)
        
        let actionsResult = try await codeParserResult
            .deriveStitchActions(bindingDeclarations: codeParserResult.bindingDeclarations,
                                 document: document)
        
        print("Derived Stitch layer data:\n\(actionsResult)")
        
        return actionsResult
    }
}

extension StitchStore {
    @MainActor
    static func displayError(failure: any Error,
                             document: StitchDocumentViewModel) -> any Error {
        log("AICodeGenRequest: getRequestTask: request.request: failure: \(failure.localizedDescription)")
        print(failure.localizedDescription)
        // Note: task clearing and menu hiding are handled by resetStreamingUIState() called by AI providers
        
        // Display error
        document.storeDelegate?.alertState.stitchFileError = .unknownError("\(failure)")
        return failure
    }
}

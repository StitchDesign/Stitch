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
             @State var color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] = []
             @State var zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] = []
             @State var dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] = [] 
            
             var body: some View {
              VStack(alignment: .center, spacing: [PortValueDescription(value: "8", value_type: "spacing")]) {
               Rectangle()
                .fill(color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
                .position(dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
                .frame([PortValueDescription(value: ["width":"300.0","height":"6.0"], value_type: "size")])
                .zIndex(zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
                .simultaneousGesture(
                 DragGesture()
                  .onChanged { value in
                   dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = [PortValueDescription(value: ["x": value.location.x, "y": value.location.y], value_type: "position")]
                  }
                )
              }
              .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
              .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
             }
            
             func updateLayerInputs() {
              let loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F = NATIVE_STITCH_PATCH_FUNCTIONS["loop || Patch"]([
               [PortValueDescription(value: 100, value_type: "number")]
              ])
              let random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
               loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
               [PortValueDescription(value: 0, value_type: "number")],
               [PortValueDescription(value: 1, value_type: "number")]
              ])
              let random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
               loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
               [PortValueDescription(value: 0, value_type: "number")],
               [PortValueDescription(value: 1, value_type: "number")]
              ])
              let random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
               loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
               [PortValueDescription(value: 0, value_type: "number")],
               [PortValueDescription(value: 1, value_type: "number")]
              ])
              let rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654 = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([
               random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D[0],
               random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596[0],
               random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9[0],
               [PortValueDescription(value: 1, value_type: "number")]
              ])
              
              // Set initial positions for rectangles if dragPosition is empty
                if dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8.isEmpty {
                  dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = PortValueDescription(value: ["x": 0, "y": 0], value_type: "position")
              }
              
              color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654[0]
              zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0]
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

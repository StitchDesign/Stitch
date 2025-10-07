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
        
        // Set streaming UI state
        document.isStreamingResponses = true
        document.streamingReasoningText = AI_THINKING_TEXT
        
        // Use provider-agnostic orchestrator
        let codeEditResult = try await makeAIRequest(
            previewWindowPrompt: previewWindowPrompt,
            userPrompt: userPrompt,
            base64Image: base64Image,
            openAIAPIKey: secrets.openAIAPIKey,
            model: model,
            verbosity: validatedVerbosity,
            reasoningEffort: document.openaiReasoningEffort.asOpenAIReasoningEffort,
            document: document,
            aiManager: aiManager,
            currentGraphEntity: document.graph.createSchema(),
            viewPortCenter: document.viewPortCenter,
            groupNodeFocused: document.groupNodeFocused?.groupNodeId
        )
        
        // Reset streaming UI state
        document.resetStreamingUIState()
        
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
                let actionsResult = try await request
                    .processRequest(userPrompt: userPrompt,
                                    document: document,
                                    aiManager: aiManager,
                                    isStreaming: false)
                
                // logToServerIfRelease("SUCCESS Patch Builder:\n\((try? actionsResult.graphData.encodeToPrintableString()) ?? "")")
                
                Task(priority: .high) { @MainActor [weak document] in
                    guard let document = document else { return }
                    
                    // Create new graph entity, which would have been updated from stream
                    let newCurrentGraphEntity = document.graph.createSchema()
                    
                    actionsResult
                        .applyAIGraph(to: document,
                                      currentGraphEntity: newCurrentGraphEntity,
                                      isStreaming: false)
                    
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
                        aiManager: StitchAIManager,
                        isStreaming: Bool) async throws -> SwiftSyntaxActionsResult {

        log("SUCCESS: userPrompt: \(userPrompt)")

        // TEMPORARY: Hardcoded test code from GitHub issue #7505
        let swiftUICode = """
struct ContentView: View {
    @State var button1Scale: [PortValueDescription] = []
    @State var button1Pulse: [PortValueDescription] = []
    @State var button2Scale: [PortValueDescription] = []
    @State var button2Pulse: [PortValueDescription] = []
    @State var button3Scale: [PortValueDescription] = []
    @State var button3Pulse: [PortValueDescription] = []

    var body: some View {
        VStack {
            ZStack {
                Ellipse()
                    .fill([PortValueDescription(value: "#D3D3D3FF", value_type: "color")])
                Text([PortValueDescription(value: "1", value_type: "string")])
            }
            .scaleEffect(button1Scale)
            .simultaneousGesture(.onTapGesture {
                button1Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
            })

            ZStack {
                Ellipse()
                    .fill([PortValueDescription(value: "#D3D3D3FF", value_type: "color")])
                Text([PortValueDescription(value: "2", value_type: "string")])
            }
            .scaleEffect(button2Scale)
            .simultaneousGesture(.onTapGesture {
                button2Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
            })

            ZStack {
                Ellipse()
                    .fill([PortValueDescription(value: "#D3D3D3FF", value_type: "color")])
                Text([PortValueDescription(value: "3", value_type: "string")])
            }
            .scaleEffect(button3Scale)
            .simultaneousGesture(.onTapGesture {
                button3Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
            })
        }
    }

    func updateLayerInputs() {
        let button1Animation = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
            button1Pulse,
            [PortValueDescription(value: 0.1, value_type: "number")],
            [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
        ])
        let button1OptionPicker = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
            button1Animation[0],
            [PortValueDescription(value: 1.0, value_type: "number")],
            [PortValueDescription(value: 0.9, value_type: "number")]
        ])
        button1Scale = button1OptionPicker[0]

        let button2Animation = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
            button2Pulse,
            [PortValueDescription(value: 0.1, value_type: "number")],
            [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
        ])
        let button2OptionPicker = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
            button2Animation[0],
            [PortValueDescription(value: 1.0, value_type: "number")],
            [PortValueDescription(value: 0.9, value_type: "number")]
        ])
        button2Scale = button2OptionPicker[0]

        let button3Animation = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
            button3Pulse,
            [PortValueDescription(value: 0.1, value_type: "number")],
            [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
        ])
        let button3OptionPicker = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
            button3Animation[0],
            [PortValueDescription(value: 1.0, value_type: "number")],
            [PortValueDescription(value: 0.9, value_type: "number")]
        ])
        button3Scale = button3OptionPicker[0]
    }
}
"""

        // let swiftUICode = try await self
        //     .createCode(document: document,
        //                 aiManager: aiManager)

        log("userPrompt: \(userPrompt)") // Very helpful to see user-prompt here again
        log("StitchAICodeCreator swiftUICode:\n\(swiftUICode)")

        // Check if the AI returned empty code or code without ContentView (and we're not streaming)
        let trimmedCode = swiftUICode.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCode.isEmpty {
            log("ERROR: AI returned invalid code (empty) for prompt: \(userPrompt)")
            throw StitchAIManagerError.emptyAIResponse
        } else if (!trimmedCode.contains("ContentView") && !isStreaming) {
            log("ERROR: AI returned invalid code (missing ContentView) for prompt: \(userPrompt)")
            throw StitchAIManagerError.emptyAIResponse
        }

        let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(swiftUICode, isStreaming: isStreaming)
        
        let actionsResult = try await codeParserResult
            .deriveStitchActions(bindingDeclarations: codeParserResult.bindingDeclarations,
                                 document: document,
                                 isStreaming: isStreaming)
        
        log("Derived Stitch layer data:\n\(actionsResult)")
        
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

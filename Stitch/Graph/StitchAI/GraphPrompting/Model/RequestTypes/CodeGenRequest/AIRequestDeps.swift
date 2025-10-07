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

//        let swiftUICode = try await self
//            .createCode(document: document,
//                        aiManager: aiManager)
        
        let swiftUICode = """
            struct ContentView: View {

                @State var button1Pulse: [PortValueDescription] = []
                @State var button1Scale: [PortValueDescription] = []
                @State var button2Pulse: [PortValueDescription] = []
                @State var button2Scale: [PortValueDescription] = []
                @State var button3Pulse: [PortValueDescription] = []
                @State var button3Scale: [PortValueDescription] = []
                @State var button4Pulse: [PortValueDescription] = []
                @State var button4Scale: [PortValueDescription] = []
                @State var button5Pulse: [PortValueDescription] = []
                @State var button5Scale: [PortValueDescription] = []
                @State var button6Pulse: [PortValueDescription] = []
                @State var button6Scale: [PortValueDescription] = []
                @State var button7Pulse: [PortValueDescription] = []
                @State var button7Scale: [PortValueDescription] = []
                @State var button8Pulse: [PortValueDescription] = []
                @State var button8Scale: [PortValueDescription] = []
                @State var button9Pulse: [PortValueDescription] = []
                @State var button9Scale: [PortValueDescription] = []
                @State var buttonStarPulse: [PortValueDescription] = []
                @State var buttonStarScale: [PortValueDescription] = []
                @State var button0Pulse: [PortValueDescription] = []
                @State var button0Scale: [PortValueDescription] = []
                @State var buttonHashPulse: [PortValueDescription] = []
                @State var buttonHashScale: [PortValueDescription] = []
                @State var callButtonPulse: [PortValueDescription] = []
                @State var callButtonScale: [PortValueDescription] = []
                @State var deleteButtonPulse: [PortValueDescription] = []
                @State var deleteButtonScale: [PortValueDescription] = []

                var body: some View {
                        VStack(alignment: .center, spacing: [PortValueDescription(value: "24", value_type: "spacing")]) {
                            Text([PortValueDescription(value: "1 (234) 567-8900", value_type: "string")])
                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .font([PortValueDescription(value: "36.0", value_type: "layerDimension")])

                            Text([PortValueDescription(value: "Add Number", value_type: "string")])
                                .foregroundColor([PortValueDescription(value: "#007AFFFF", value_type: "color")])
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])

                            Spacer()


                            VStack(alignment: .center, spacing: [PortValueDescription(value: "20", value_type: "spacing")]) {
                                HStack(alignment: .center, spacing: [PortValueDescription(value: "30", value_type: "spacing")]) {
                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])

                                        Text([PortValueDescription(value: "1", value_type: "string")])
                                            .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                        .scaleEffect(button1Scale)
                                        .onTapGesture {
                                            button1Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                        VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                            Text([PortValueDescription(value: "2", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                            Text([PortValueDescription(value: "ABC", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                        }
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                        .scaleEffect(button2Scale)
                                        .onTapGesture {
                                            button2Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                        VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                            Text([PortValueDescription(value: "3", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                            Text([PortValueDescription(value: "DEF", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                        }
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                        .scaleEffect(button3Scale)
                                        .onTapGesture {
                                            button3Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                                HStack(alignment: .center, spacing: [PortValueDescription(value: "30", value_type: "spacing")]) {
                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                        VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                            Text([PortValueDescription(value: "4", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                            Text([PortValueDescription(value: "GHI", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                        }
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                        .scaleEffect(button4Scale)
                                        .onTapGesture {
                                            button4Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                        VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                            Text([PortValueDescription(value: "5", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                            Text([PortValueDescription(value: "JKL", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                        }
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                        .scaleEffect(button5Scale)
                                        .onTapGesture {
                                            button5Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                        VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                            Text([PortValueDescription(value: "6", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                            Text([PortValueDescription(value: "MNO", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                        }
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                        .scaleEffect(button6Scale)
                                        .onTapGesture {
                                            button6Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                                HStack(alignment: .center, spacing: [PortValueDescription(value: "30", value_type: "spacing")]) {
                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                        VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                            Text([PortValueDescription(value: "7", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                            Text([PortValueDescription(value: "PQRS", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                        }
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                        .scaleEffect(button7Scale)
                                        .onTapGesture {
                                            button7Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                        VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                            Text([PortValueDescription(value: "8", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                            Text([PortValueDescription(value: "TUV", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                        }
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                        .scaleEffect(button8Scale)
                                        .onTapGesture {
                                            button8Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                        VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                            Text([PortValueDescription(value: "9", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                            Text([PortValueDescription(value: "WXYZ", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                        }
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                        .scaleEffect(button9Scale)
                                        .onTapGesture {
                                            button9Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                                HStack(alignment: .center, spacing: [PortValueDescription(value: "30", value_type: "spacing")]) {
                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                        Text([PortValueDescription(value: "*", value_type: "string")])
                                            .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .font([PortValueDescription(value: "40.0", value_type: "layerDimension")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["height":"hug","width":"hug"], value_type: "size")])
                                        .scaleEffect(buttonStarScale)
                                        .onTapGesture {
                                            buttonStarPulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])

                                        VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                            Text([PortValueDescription(value: "0", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                                .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                            Text([PortValueDescription(value: "+", value_type: "string")])
                                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])

                                        }
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["height":"hug","width":"hug"], value_type: "size")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["height":"hug","width":"hug"], value_type: "size")])
                                        .scaleEffect(button0Scale)
                                        .onTapGesture {
                                            button0Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                    ZStack(alignment: .center) {
                                        Ellipse()
                                            .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])

                                        Text([PortValueDescription(value: "#", value_type: "string")])
                                            .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                            .font([PortValueDescription(value: "40.0", value_type: "layerDimension")])

                                    }
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                        .scaleEffect(buttonHashScale)
                                        .onTapGesture {
                                            buttonHashPulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                        }

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                            Spacer()


                            HStack(alignment: .center, spacing: [PortValueDescription(value: "60", value_type: "spacing")]) {
                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value: "#FF9500FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["width":"70.0","height":"70.0"], value_type: "size")])

                                    Text([PortValueDescription(value: "📞", value_type: "string")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["height":"hug","width":"hug"], value_type: "size")])
                                    .scaleEffect(callButtonScale)
                                    .onTapGesture {
                                        callButtonPulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                    }

                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .frame([PortValueDescription(value: ["height":"50.0","width":"50.0"], value_type: "size")])

                                    Text([PortValueDescription(value: "⌫", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "24.0", value_type: "layerDimension")])

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                    .scaleEffect(deleteButtonScale)
                                    .onTapGesture {
                                        deleteButtonPulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                    }

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                        }
                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                            .padding([PortValueDescription(value: ["left":20,"bottom":40,"right":20,"top":40], value_type: "padding")])

                }

                func updateLayerInputs() {
                    let optionPicker1 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        button1Pulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animation1 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPicker1[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    button1Scale = animation1[0]

                    let optionPicker2 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        button2Pulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animation2 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPicker2[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    button2Scale = animation2[0]

                    let optionPicker3 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        button3Pulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animation3 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPicker3[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    button3Scale = animation3[0]

                    let optionPicker4 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        button4Pulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animation4 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPicker4[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    button4Scale = animation4[0]

                    let optionPicker5 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        button5Pulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animation5 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPicker5[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    button5Scale = animation5[0]

                    let optionPicker6 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        button6Pulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animation6 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPicker6[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    button6Scale = animation6[0]

                    let optionPicker7 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        button7Pulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animation7 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPicker7[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    button7Scale = animation7[0]

                    let optionPicker8 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        button8Pulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animation8 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPicker8[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    button8Scale = animation8[0]

                    let optionPicker9 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        button9Pulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animation9 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPicker9[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    button9Scale = animation9[0]

                    let optionPickerStar = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        buttonStarPulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animationStar = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPickerStar[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    buttonStarScale = animationStar[0]

                    let optionPicker0 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        button0Pulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animation0 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPicker0[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    button0Scale = animation0[0]

                    let optionPickerHash = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        buttonHashPulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animationHash = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPickerHash[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    buttonHashScale = animationHash[0]

                    let optionPickerCall = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        callButtonPulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animationCall = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPickerCall[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    callButtonScale = animationCall[0]

                    let optionPickerDelete = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        deleteButtonPulse,
                        [PortValueDescription(value: 1, value_type: "number")],
                        [PortValueDescription(value: 0.85, value_type: "number")]
                    ])
                    let animationDelete = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                        optionPickerDelete[0],
                        [PortValueDescription(value: 0.15, value_type: "number")],
                        [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
                    ])
                    deleteButtonScale = animationDelete[0]
                }


            }

            """

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

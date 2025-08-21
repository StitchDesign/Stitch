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
        
//        let swiftUICode: String = try await self
//            .createCode(document: document,
//                        aiManager: aiManager,
//                        dataGlossaryPrompt: dataGlossaryPrompt)
        
        let swiftUICode: String = """
            struct ContentView: some View {
                @State var callButtonScale: [PortValueDescription] = [
                    PortValueDescription(value: 1, value_type: "number")
                ]

                var body: some View {
                    VStack(alignment: .center, spacing: [PortValueDescription(value_type: "spacing", value: "24")]) {
                        Text([PortValueDescription(value_type: "string", value: "1 (234) 567-8900")])
                            .layerId("B32D1374-4367-4DBB-9FDF-B57CFEF89947")

                        Text([PortValueDescription(value_type: "string", value: "Add Number")])
                            .foregroundColor([PortValueDescription(value_type: "color", value: "#007AFFFF")])
                            .layerId("03ADD037-B82A-4081-872B-7E3A53BFF1D2")

                        VStack(alignment: .center, spacing: [PortValueDescription(value: "16", value_type: "spacing")]) {
                            HStack(alignment: .center, spacing: [PortValueDescription(value_type: "spacing", value: "16")]) {
                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value_type: "color", value: "#E5E5EAFF")])
                                        .frame([PortValueDescription(value_type: "size", value: { width: "80.0", height: "80.0" })])
                                        .layerId("AF6E249E-6AF9-4AB3-95B2-D3882D0AC643")

                                    VStack(alignment: .center, spacing: [PortValueDescription(value_type: "spacing", value: "2")]) {
                                        Text([PortValueDescription(value: "7", value_type: "string")])
                                            .layerId("771BC61B-22CE-4032-821E-EC08315F9539")

                                        Text([PortValueDescription(value_type: "string", value: "PQRS")])
                                            .layerId("A704B200-A3B9-40F1-8DB9-F0B7AF83F971")
                                    }
                                    .layerId("1D60405A-4436-4154-84E1-7786CCBF182F")
                                }
                                .layerId("E505D356-8F79-437F-A777-E896778D9660")

                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value_type: "color", value: "#E5E5EAFF")])
                                        .frame([PortValueDescription(value_type: "size", value: { height: "80.0", width: "80.0" })])
                                        .layerId("0FB3B2A0-B1A6-44B9-B4A4-1BFBE3AE41AF")

                                    VStack(alignment: .center, spacing: [PortValueDescription(value: "2", value_type: "spacing")]) {
                                        Text([PortValueDescription(value: "WXYZ", value_type: "string")])
                                            .layerId("4B2C6C10-84D0-4637-A384-69D8C12C1D5A")

                                        Text([PortValueDescription(value: "9", value_type: "string")])
                                            .layerId("6239B0ED-2CAF-4CED-8132-B5BED764D59A")
                                    }
                                    .layerId("4503D955-9FDC-4950-AFCF-CA605949227E")
                                }
                                .layerId("2F37F253-0293-4CCD-82D6-04BEF7A5B224")

                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value_type: "color", value: "#E5E5EAFF")])
                                        .frame([PortValueDescription(value_type: "size", value: { width: "80.0", height: "80.0" })])
                                        .layerId("B85A7FAD-BB1A-42E6-A53C-422146C1CC69")

                                    VStack(alignment: .center, spacing: [PortValueDescription(value_type: "spacing", value: "2")]) {
                                        Text([PortValueDescription(value_type: "string", value: "TUV")])
                                            .layerId("5CECAC67-960A-4F51-8AF4-10B4E333E689")

                                        Text([PortValueDescription(value_type: "string", value: "8")])
                                            .layerId("6F240CF1-A63B-492B-9514-A84A3E905801")
                                    }
                                    .layerId("8B265B4E-825C-4217-9F0D-99616B4433B2")
                                }
                                .layerId("095E3CF8-25CF-4E59-BB28-E134725130F9")
                            }
                            .layerId("EAE1ADE8-24AB-4F1A-A0A5-C5B3A632F113")

                            HStack(alignment: .center, spacing: [PortValueDescription(value: "16", value_type: "spacing")]) {
                                ZStack(alignment: .center) {
                                    VStack(alignment: .center, spacing: [PortValueDescription(value_type: "spacing", value: "2")]) {
                                        Text([PortValueDescription(value: "6", value_type: "string")])
                                            .layerId("9A7C7601-CFC6-44C5-B127-F4EF41149709")

                                        Text([PortValueDescription(value: "MNO", value_type: "string")])
                                            .layerId("65734194-EDDD-4B78-9F9D-B6B1B4DC429C")
                                    }
                                    .layerId("E29C063C-1B62-4621-BBE2-DDE1C3084C6F")

                                    Ellipse()
                                        .fill([PortValueDescription(value_type: "color", value: "#E5E5EAFF")])
                                        .frame([PortValueDescription(value_type: "size", value: { height: "80.0", width: "80.0" })])
                                        .layerId("DB92B715-3D2D-4236-9ACE-F49548C9DDFF")
                                }
                                .layerId("02866D3A-C9B0-4353-8501-765AFACAD9E2")

                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value: "#E5E5EAFF", value_type: "color")])
                                        .frame([PortValueDescription(value: { height: "80.0", width: "80.0" }, value_type: "size")])
                                        .layerId("61CB366B-BCE0-4776-9593-2B7B189DE52A")

                                    VStack(alignment: .center, spacing: [PortValueDescription(value: "2", value_type: "spacing")]) {
                                        Text([PortValueDescription(value: "4", value_type: "string")])
                                            .layerId("7A7F2512-C8AC-4822-9138-B479E8AB8A65")

                                        Text([PortValueDescription(value: "GHI", value_type: "string")])
                                            .layerId("5B640B5C-956B-4E5D-A189-FF7F95C5477C")
                                    }
                                    .layerId("22700158-A450-4CCF-AE34-D20DBC09DD47")
                                }
                                .layerId("FC198E6A-1DF3-4EE0-8AFF-8A85D083BBCF")

                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value: "#E5E5EAFF", value_type: "color")])
                                        .frame([PortValueDescription(value: { width: "80.0", height: "80.0" }, value_type: "size")])
                                        .layerId("95B76F5C-B51E-404F-806A-052BBC6F633E")

                                    VStack(alignment: .center, spacing: [PortValueDescription(value: "2", value_type: "spacing")]) {
                                        Text([PortValueDescription(value_type: "string", value: "5")])
                                            .layerId("F366BE41-0981-44EF-A0A3-795A12077FA3")

                                        Text([PortValueDescription(value_type: "string", value: "JKL")])
                                            .layerId("ABB542E8-D93E-4673-A6AB-85D5BE119C3B")
                                    }
                                    .layerId("A37FA407-28A4-4DCA-A093-A1CE0B20FBD9")
                                }
                                .layerId("670E7DDE-77E3-4E3C-A675-05639DCD9E75")
                            }
                            .layerId("A1E973D8-565E-41C4-A14B-03946A93DD9F")

                            HStack(alignment: .center, spacing: [PortValueDescription(value: "40", value_type: "spacing")]) {
                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value: "#FF9500FF", value_type: "color")])
                                        .frame([PortValueDescription(value: { height: "80.0", width: "80.0" }, value_type: "size")])
                                        .scaleEffect(callButtonScale)
                                        .layerId("F0BAFCC9-42BF-428C-B0FC-C045D34567F1")
                                }
                                .layerId("0CBDE32D-5B39-49FF-B03B-73B401C1234C")
                            }
                            .layerId("6DB5E463-45A7-4373-A9EF-357CA65524B7")

                            ZStack(alignment: .center) {
                                Rectangle()
                                    .fill([PortValueDescription(value: "#E5E5EAFF", value_type: "color")])
                                    .frame([PortValueDescription(value: { height: "40.0", width: "40.0" }, value_type: "size")])
                                    .cornerRadius([PortValueDescription(value: 8, value_type: "number")])
                                    .layerId("B62E0796-56AC-48C6-9261-CD5A7FF9E57D")
                            }
                            .layerId("3147B626-08F4-495F-8AB0-CE3797FB5168")

                            HStack(alignment: .center, spacing: [PortValueDescription(value: "16", value_type: "spacing")]) {
                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value_type: "color", value: "#E5E5EAFF")])
                                        .frame([PortValueDescription(value: { height: "80.0", width: "80.0" }, value_type: "size")])
                                        .layerId("6B8C28AD-0F95-465C-A28F-9049CB315F42")

                                    VStack(alignment: .center, spacing: [PortValueDescription(value_type: "spacing", value: "2")]) {
                                        Text([PortValueDescription(value: "", value_type: "string")])
                                            .layerId("BD2AC846-A5FF-4CA8-81B3-748236D09B62")

                                        Text([PortValueDescription(value_type: "string", value: "1")])
                                            .layerId("7CE5F80F-8B54-4D08-BB39-24D18166F09F")
                                    }
                                    .layerId("8BE10110-2E52-4FCE-B8AF-3FF5F55DB4F8")
                                }
                                .layerId("F3AF8B7E-A112-47F7-BFC3-28EA5E9F77E3")

                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value_type: "color", value: "#E5E5EAFF")])
                                        .frame([PortValueDescription(value: { width: "80.0", height: "80.0" }, value_type: "size")])
                                        .layerId("0FD8CE4C-8986-42AF-B517-CAF983EBA585")

                                    VStack(alignment: .center, spacing: [PortValueDescription(value: "2", value_type: "spacing")]) {
                                        Text([PortValueDescription(value_type: "string", value: "3")])
                                            .layerId("6827BF01-DF05-4933-8B8C-023A83457832")

                                        Text([PortValueDescription(value_type: "string", value: "DEF")])
                                            .layerId("3D2261D8-4C47-4080-BF47-107D00192BDA")
                                    }
                                    .layerId("16A96F56-0CF9-4692-8DEA-F0F20D745846")
                                }
                                .layerId("F60D8D28-7244-4D70-BDBD-D41F509311C0")

                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value_type: "color", value: "#E5E5EAFF")])
                                        .frame([PortValueDescription(value_type: "size", value: { height: "80.0", width: "80.0" })])
                                        .layerId("76206FAC-82E4-4AC2-9E82-3BC92D25CCD8")

                                    VStack(alignment: .center, spacing: [PortValueDescription(value_type: "spacing", value: "2")]) {
                                        Text([PortValueDescription(value: "ABC", value_type: "string")])
                                            .layerId("003E5FCA-11EC-4EC0-8DBA-44B706D56A94")

                                        Text([PortValueDescription(value: "2", value_type: "string")])
                                            .layerId("3E13F0EB-3B31-4E62-BC5E-9774E28CAF44")
                                    }
                                    .layerId("C5CB19A1-9C66-40FF-B3A5-6D7139E58B7F")
                                }
                                .layerId("6E638C4F-BC8F-451D-9F0B-165A38EF68AC")
                            }
                            .layerId("706D627E-139D-44A5-90DF-6D211C766E73")

                            HStack(alignment: .center, spacing: [PortValueDescription(value: "16", value_type: "spacing")]) {
                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value_type: "color", value: "#E5E5EAFF")])
                                        .frame([PortValueDescription(value_type: "size", value: { width: "80.0", height: "80.0" })])
                                        .layerId("56C9038C-4D05-49DA-82DD-6C3209FA7662")

                                    VStack(alignment: .center, spacing: [PortValueDescription(value_type: "spacing", value: "2")]) {
                                        Text([PortValueDescription(value_type: "string", value: "+")])
                                            .layerId("BF1D868A-3C9A-4E09-962F-65C08EF331BC")

                                        Text([PortValueDescription(value_type: "string", value: "0")])
                                            .layerId("580AFC55-E030-4E2E-9087-987635A433E8")
                                    }
                                    .layerId("3C4315CF-4B9F-4A21-B8AA-2C2090BBBE3E")
                                }
                                .layerId("691DBC9F-D330-4A50-B24D-09B3B909036F")

                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value_type: "color", value: "#E5E5EAFF")])
                                        .frame([PortValueDescription(value_type: "size", value: { height: "80.0", width: "80.0" })])
                                        .layerId("15F61DDB-D000-49B1-BC3F-F20083D052CD")

                                    Text([PortValueDescription(value: "*", value_type: "string")])
                                        .layerId("2B0A66C9-1985-4BA1-9C97-D0F81FA25BBB")
                                }
                                .layerId("44D0BB46-E427-4AA2-B2E2-DEADABF5620B")

                                ZStack(alignment: .center) {
                                    Ellipse()
                                        .fill([PortValueDescription(value_type: "color", value: "#E5E5EAFF")])
                                        .frame([PortValueDescription(value_type: "size", value: { width: "80.0", height: "80.0" })])
                                        .layerId("34DA860A-EB29-4E83-80C9-A873220E47A8")

                                    Text([PortValueDescription(value_type: "string", value: "#")])
                                        .layerId("D66C5309-803A-41A4-808D-04E2D3E703F4")
                                }
                                .layerId("D4366063-DF04-4462-B1DA-21AD82573E6E")
                            }
                            .layerId("7B606289-BB05-4771-BE80-8432B2C5ADE7")
                        }
                        .layerId("B6911AFB-82B1-49B3-9C96-F97248F451E9")
                    }
                    .layerId("0FA6E40E-1949-4AF4-842A-6E5ED7607872")
                }

                func updateLayerInputs() {
                    let pressInteraction_F0BA = NATIVE_STITCH_PATCH_FUNCTIONS["pressInteraction || Patch"]([
                        [PortValueDescription(value: "F0BAFCC9-42BF-428C-B0FC-C045D34567F1", value_type: "layer")],
                        [PortValueDescription(value: true, value_type: "bool")],
                        [PortValueDescription(value: 0, value_type: "number")]
                    ])
                    let optionPicker_S = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                        pressInteraction_F0BA[0],
                        [PortValueDescription(value: 0.9, value_type: "number")],
                        [PortValueDescription(value: 1, value_type: "number")]
                    ])
                    callButtonScale = optionPicker_S[0]
                }
            }
            """

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

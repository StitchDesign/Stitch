//
//  AICodeGenRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

struct AICodeGenRequest: StitchAIRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AICodeGenRequestBody
    static let willStream: Bool = false
    
    @MainActor
    init(prompt: String,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AICodeGenRequestBody(prompt: prompt)
    }
    
    @MainActor
    func willRequest(document: StitchDocumentViewModel,
                     canShareData: Bool,
                     requestTask: Self.RequestTask) {
        // Nothing to do
    }
    
    static func validateResponse(decodedResult: String) throws -> String {
        decodedResult
    }
    
    @MainActor
    func onSuccessfulDecodingChunk(result: String,
                                   currentAttempt: Int) {
        fatalErrorIfDebug()
    }
    
    static func buildResponse(from streamingChunks: [String]) throws -> String {
        // Unsupported
        fatalError()
    }
    
    @MainActor
    static func getRequestTask(userPrompt: String,
                               document: StitchDocumentViewModel) throws -> Task<Result<AIPatchBuilderRequest.FinalDecodedResult, any Error>,
                                                                                 Never> {
        let request = try AICodeGenRequest(
            prompt: userPrompt)
        
        return Task(priority: .high) { [weak document] in            
            guard let document = document,
                  let aiManager = document.aiManager else {
                log("AICodeGenRequest: getRequestTask: no document or ai manager", .logToServer)
                
                if let document: StitchDocumentViewModel = document {
                    return .failure(self.displayError(failure: StitchAIManagerError.secretsNotFound,
                                                      document: document))
                } else {
                    return .failure(StitchAIManagerError.secretsNotFound)
                }
            }
            
            let result = await request.request(document: document,
                                               aiManager: aiManager)
            switch result {
            case .success(let swiftUISourceCode):
                logToServerIfRelease("SUCCESS Code Gen:\n\(swiftUISourceCode)")
                
                guard let parsedVarBody = VarBodyParser.extract(from: swiftUISourceCode) else {
                    logToServerIfRelease("SwiftUISyntaxError.couldNotParseVarBody.localizedDescription: \(SwiftUISyntaxError.couldNotParseVarBody.localizedDescription)")
                    return .failure(self.displayError(failure: SwiftUISyntaxError.couldNotParseVarBody,
                                                      document: document))
                }
                
                logToServerIfRelease("SUCCESS parsedVarBody:\n\(parsedVarBody)")
                
                let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(parsedVarBody)
                var allDiscoveredErrors = codeParserResult.caughtErrors

                guard let viewNode = codeParserResult.rootView else {
                    logToServerIfRelease("SwiftUISyntaxError.viewNodeNotFound.localizedDescription: \(SwiftUISyntaxError.viewNodeNotFound.localizedDescription)")
                    return .failure(self.displayError(failure: SwiftUISyntaxError.viewNodeNotFound,
                                                      document: document))
                }
                
                do {
                    let actionsResult = try viewNode.deriveStitchActions()
                    let layerDataList = actionsResult.actions
                    allDiscoveredErrors += actionsResult.caughtErrors
                    
                    let patchBuilderRequest = try AIPatchBuilderRequest(
                        prompt: userPrompt,
                        swiftUISourceCode: swiftUISourceCode,
                        layerDataList: layerDataList)
                    
                    let patchBuilderResult = await patchBuilderRequest
                        .request(document: document,
                                 aiManager: aiManager)
                    
                    switch patchBuilderResult {
                    case .success(let patchBuildResult):
                        logToServerIfRelease("SUCCESS Patch Builder:\n\(patchBuildResult)")
                        
                        DispatchQueue.main.async { [weak document] in
                            guard let document = document else { return }
                            
                            do {
                                let graphData = CurrentAIPatchBuilderResponseFormat
                                    .GraphData(layer_data_list: layerDataList,
                                               patch_data: patchBuildResult)
                                try graphData.applyAIGraph(to: document)
                                
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
                        
                        return .success(patchBuildResult)
                        
                    case .failure(let failure):
                        logToServerIfRelease("AICodeGenRequest: getRequestTask: patchBuilderResult: failure: \(failure.localizedDescription)")
                        return .failure(Self.displayError(failure: failure,
                                                          document: document))
                    }
                } catch {
                    return .failure(Self.displayError(failure: error,
                                                      document: document))
                }
                
            case .failure(let failure):
                logToServerIfRelease("AICodeGenRequest: getRequestTask: request.request: failure: \(failure.localizedDescription)")
                return .failure(Self.displayError(failure: failure,
                                                  document: document))
            }
        }
    }
    
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

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
                               document: StitchDocumentViewModel) throws -> Task<AIPatchBuilderRequest.FinalDecodedResult,
    any Error> {
        let request = try AICodeGenRequest(
            prompt: userPrompt)
        
        return Task(priority: .high) { [weak document] in
            guard let document = document,
                  let aiManager = document.aiManager else {
                log("AICodeGenRequest: getRequestTask: no document or ai manager", .logToServer)
                throw StitchAIManagerError.secretsNotFound
            }
            
            let result = await request.request(document: document,
                                               aiManager: aiManager)
            switch result {
            case .success(let swiftUISourceCode):
                print("SUCCESS Code Gen:\n\(swiftUISourceCode)")
                
                guard let viewNode = SwiftUIViewVisitor.parseSwiftUICode(swiftUISourceCode) else {
                    throw SwiftUISyntaxError.viewNodeNotFound
                }
                
                guard let layerData = try viewNode.deriveStitchActions() else {
                    throw SwiftUISyntaxError.rootLayerNotFound
                }
                
                let patchBuilderRequest = try AIPatchBuilderRequest(
                    prompt: userPrompt,
                    swiftUISourceCode: swiftUISourceCode,
                    layerData: layerData)
                
                let patchBuilderResult = await patchBuilderRequest
                    .request(document: document,
                             aiManager: aiManager)
                
                switch patchBuilderResult {
                case .success(let patchBuildResult):
                    print("SUCCESS Patch Builder:\n\(patchBuildResult)")
                    
                    DispatchQueue.main.async { [weak document] in
                        guard let document = document else { return }
                        
                        do {
                            let graphData = CurrentAIPatchBuilderResponseFormat
                                .GraphData(layer_data: layerData,
                                           patch_data: patchBuildResult)
                            try graphData.applyAIGraph(to: document)
                        } catch {
                            log("Error applying AI graph: \(error.localizedDescription)")
                            document.storeDelegate?.alertState.stitchFileError = .unknownError(error.localizedDescription)
                        }

                        document.aiManager?.currentTaskTesting = nil
                        document.insertNodeMenuState.show = false
                    }
                    
                    return patchBuildResult
                    
                case .failure(let failure):
                    log("AICodeGenRequest: getRequestTask: patchBuilderResult: failure: \(failure.localizedDescription)", .logToServer)
                    print(failure.localizedDescription)
                    document.aiManager?.currentTaskTesting = nil
                    document.insertNodeMenuState.show = false
                    throw failure
                }
                
            case .failure(let failure):
                log("AICodeGenRequest: getRequestTask: request.request: failure: \(failure.localizedDescription)", .logToServer)
                print(failure.localizedDescription)
                document.aiManager?.currentTaskTesting = nil
                document.insertNodeMenuState.show = false
                throw failure
            }
        }
    }
}

//
//  AIPatchServiceRequest.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

import SwiftUI

struct AIPatchServiceRequest: StitchAIRequestable {
    let id: UUID
    let userPrompt: String             // User's input prompt
    let config: OpenAIRequestConfig // Request configuration settings
    let body: AIPatchServiceRequestBody
    static let willStream: Bool = false
    
    @MainActor
    init(prompt: String,
         config: OpenAIRequestConfig = .default) throws {
        
        // The id of the user's inference call; does not change across retries etc.
        self.id = .init()
        
        self.userPrompt = prompt
        self.config = config
        
        // Construct http payload
        self.body = try AIPatchServiceRequestBody(prompt: prompt)
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
        let request = try AIPatchServiceRequest(
            prompt: userPrompt)
        
        return Task(priority: .high) { [weak document] in
            guard let document = document,
                  let aiManager = document.aiManager else {
                throw StitchAIManagerError.secretsNotFound
            }
            
            let result = await request.request(document: document,
                                               aiManager: aiManager)
            switch result {
            case .success(let jsSourceCode):
                print("SUCCESS Patch Service:\n\(jsSourceCode)")
                
                let patchBuilderRequest = try AIPatchBuilderRequest(
                    prompt: userPrompt,
                    jsSourceCode: jsSourceCode,
                    
                    // Nil for now, provides option later for mapping
                    layerList: nil)
                
                let patchBuilderResult = await patchBuilderRequest
                    .request(document: document,
                             aiManager: aiManager)
                
                switch patchBuilderResult {
                case .success(let patchBuildResult):
                    print("SUCCESS Patch Builder:\n\(patchBuildResult)")
                    
                    await MainActor.run { [weak document] in
                        guard let document = document else { return }
                        document.aiManager?.currentTaskTesting = nil
                        
                        do {
                            try patchBuildResult.apply(to: document)
                        } catch {
                            fatalErrorIfDebug(error.localizedDescription)
                        }
                    }
                    
                    return patchBuildResult
                    
                case .failure(let failure):
                    print(failure.localizedDescription)
                    document.aiManager?.currentTaskTesting = nil
                    throw failure
                }
                
            case .failure(let failure):
                print(failure.localizedDescription)
                document.aiManager?.currentTaskTesting = nil
                throw failure
            }
        }
    }
}

//
//  JsonStreamTest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/8/25.
//

import SwiftUI
import JsonStream
import SwiftyJSON


struct ChunkProcessed: StitchStoreEvent {
    let newStep: Step
    let request: AIGraphCreationRequest
    let currentAttempt: Int
    
    @MainActor
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        
        log("ChunkProcessed: newStep: \(newStep)")
        
        guard let state = store.currentDocument else {
            log("ChunkProcessed: no current document")
            return .noChange
        }
        
        guard let aiManager = state.aiManager else {
            fatalErrorIfDebug("ChunkProcessed: no ai manager")
            // TODO: show error modal to user?
            return .noChange
        }
                
        // Helpful for debug to keep around the streamed-in Steps while a given task is active
        state.llmRecording.streamedSteps.append(newStep)
            
        // Parsing the Step is not async, but retry-on-failure *is*, since we wait some small delay.
        let parseAttempt: Result<any StepActionable, StitchAIStepHandlingError> = newStep.parseAsStepAction()
        
        Task(priority: .high) { [weak aiManager] in
            
            guard let aiManager = aiManager,
                  let nodeIdMap = aiManager.currentTask?.nodeIdMap else {
                log("ChunkProcessed: Did not have AI manager and/or current task")
                return
            }
            
            switch parseAttempt {
                
            case .failure(let parsingError):
                log("ChunkProcessed: FAILED TO APPLY LLM ACTIONS: parsingError: \(parsingError) for request.prompt: \(request.userPrompt)")
                if parsingError.shouldRetryRequest {
                    await aiManager.retryOrShowErrorModal(
                        request: request,
                        steps: Array(state.llmRecording.streamedSteps),
                        attempt: currentAttempt,
                        document: state,
                        canShareAIRetries: StitchStore.canShareAIData)
                }
                
            case .success(var parsedStep):
                log("ChunkProcessed: successfully parsed step, parsedStep: \(parsedStep)")
                                
                // see note on `provideGenuinelyUniqueUUIDForAIStep`
                let (updatedParsedStep,
                     updatedNodeIdMap) = provideGenuinelyUniqueUUIDForAIStep(newStep,
                                                                             parsedStep,
                                                                             nodeIdMap: nodeIdMap)
                parsedStep = updatedParsedStep
                aiManager.currentTask?.nodeIdMap = updatedNodeIdMap
                
                
                if let validationError = state.onNewStepReceived(originalSteps: state.llmRecording.actions,
                                                                 newStep: parsedStep) {
                    log("ChunkProcessed: FAILED TO APPLY LLM ACTIONS: validationError: \(validationError) for request.prompt: \(request.userPrompt)")
                    if validationError.shouldRetryRequest {
                        await aiManager.retryOrShowErrorModal(
                            request: request,
                            steps: Array(state.llmRecording.streamedSteps),
                            attempt: currentAttempt,
                            document: state,
                            canShareAIRetries: StitchStore.canShareAIData)
                    }
                } else {
                    log("ChunkProcessed: SUCCESSFULLY APPLIED NEW STEP")
                }
            }
        } // Task
        
        
        // TODO: actually, the Task should be returned as a side-effect
        return .noChange
    }
}

 
// Note: OpenAI can apparently send us the same UUIDs across completely different requests. So, we never actually use the `Step.nodeId: StitchAIUUID`; instead, we create a new, guaranteed-always-unique NodeId and update the parsed steps as they come in.
// TODO: update the system prompt to force OpenAI to send genuinely unique UUIDs everytime
func provideGenuinelyUniqueUUIDForAIStep<T: StepActionable>(
    _ unparsedStep: Step,
    _ parsedStep: T,
    nodeIdMap: [StitchAIUUID: NodeId]) -> (updatedParsedStep: T,
                                           updatedNodeIdMap: [StitchAIUUID: NodeId]) {
    
    var nodeIdMap = nodeIdMap
    
    if unparsedStep.stepType.introducesNewNode,
       let newStepNodeId: StitchAIUUID = unparsedStep.nodeId {
        // log("ChunkProcessed: nodeIdMap was: \(nodeIdMap)")
        nodeIdMap.updateValue(
            // a new, ALWAYS unique Stitch node id
            NodeId(),
            // the node id OpenAI sent us, may be repeated across requests
            forKey: newStepNodeId
        )
        log("ChunkProcessed: nodeIdMap is now: \(nodeIdMap)")
    }
    
    // log("ChunkProcessed: parsedStep was: \(parsedStep)")
    let updatedParsedStep = parsedStep.remapNodeIds(nodeIdMap: nodeIdMap)
    log("ChunkProcessed: parsedStep is now: \(updatedParsedStep)")
    
    return (updatedParsedStep, nodeIdMap)
}

extension StitchAIManager {
    private func fetchWithRetries(
        _ urlRequest: URLRequest,
        maxRetries: Int = 3
    ) async throws -> (Data, URLResponse) {
        var attempt = 0
        var delay: UInt64 = 500_000_000  // 0.5s

        while true {
            do {
                return try await aiSession.data(for: urlRequest)
            } catch let err as URLError where err.code == .networkConnectionLost && attempt < maxRetries {
                attempt += 1
                try await Task.sleep(nanoseconds: delay)
                delay *= 2
                continue
            }
        }
    }
    func makeRequest<AIRequest>(for urlRequest: URLRequest,
                                with request: AIRequest,
                                attempt: Int,
                                document: StitchDocumentViewModel) async -> Result<AIRequest.RequestResponsePayload, Error> where AIRequest: StitchAIRequestable {
        if request.willStream {
            return await self.openStream(for: urlRequest,
                                   with: request,
                                   attempt: attempt)
        } else {
            return await self.makeNonStreamedRequest(for: urlRequest,
                                                     with: request,
                                                     attempt: attempt,
                                                     document: document)
        }
    }
    
    private func makeNonStreamedRequest<AIRequest>(for urlRequest: URLRequest,
                                                   with request: AIRequest,
                                                   attempt: Int,
                                                   document: StitchDocumentViewModel) async -> Result<AIRequest.RequestResponsePayload, Error> where AIRequest: StitchAIRequestable {
        let result = await Result { @Sendable in
            try await fetchWithRetries(urlRequest)
        }
                
        switch result {
        case .success(let success):
            let jsonResponse = String(data: success.0, encoding: .utf8)
            print("Successful AI response:\n\(jsonResponse ?? "none")")
            do {
                let response = try JSONDecoder().decode(OpenAIResponse.self, from: success.0)
                
                guard let firstChoice = response.choices.first else {
                    fatalErrorIfDebug()
                    return .failure(StitchAIManagerError.firstChoiceNotDecoded)
                }
                
//                let initialDecodedResult = try AIRequest.parseOpenAIResponse(message: firstChoice.message)
//                let result = try AIRequest.validateResponse(decodedResult: initialDecodedResult)
                
                return .success((firstChoice.message, success.1))
            } catch {
                print(error)
                return .failure(StitchAIManagerError.responseDecodingFailure("\(error)"))
            }
        case .failure(let failure):
            print("makeNonStreamedRequest failure: \(failure)")
            return .failure(failure)
        }
    }
    
    // TODO: streamData opens a stream; the stream sends us events (from the server) that we respond to
    
    // MARK: - Streaming helpers
    /// Perform an HTTP request and stream back the response, printing each chunk as it arrives.
    private func openStream<AIRequest>(for urlRequest: URLRequest,
                                       with request: AIRequest,
                                       attempt: Int) async -> Result<AIRequest.RequestResponsePayload, Error> where AIRequest: StitchAIRequestable {
        
        var decodedChunks: [AIRequest.TokenDecodedResult] = []
        
        var currentChunk: [UInt8] = []
        
        // Tracks every token received, never reset
        var allContentTokens = [String]()
        
        // Tracks tokens; 'semi-reset' when we encounter a new step
        var contentTokensSinceLastResponse = [String]()
        
        // `bytes(for:)` returns an `AsyncSequence` of individual `UInt8`s
        // let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
        
        let fetchedBytes = await Result {
            try await URLSession.shared.bytes(for: urlRequest)
        }
        
        switch fetchedBytes {
            
        case .failure(let error):
            return .failure(error)
            
        case .success((let bytes, let response)):

            do {
                for try await byte in bytes {
                    
                    currentChunk.append(byte)
                    
                    guard byte == 10, !currentChunk.isEmpty else {
                        continue
                    }
                    
                    if let chunkDataString = String(data: Data(currentChunk), encoding: .utf8),
                       let contentToken = chunkDataString.getContentToken() {
                        
                        allContentTokens.append(contentToken)
                        contentTokensSinceLastResponse.append(contentToken)
                        
                        if let (newStep, newTokens) = AIRequest.decodeFromTokenStream(tokens: contentTokensSinceLastResponse) {
                            decodedChunks.append(newStep)
                            contentTokensSinceLastResponse = newTokens
                            
                            DispatchQueue.main.async {
                                request.onSuccessfulDecodingChunk(result: newStep,
                                                                  currentAttempt: attempt)
                            }
                        }
                    }
                    
                    // Clear the current chunk
                    currentChunk.removeAll(keepingCapacity: true)
                } // for byte in bytes
                
                // DEBUG
                // log("allContentTokens: \(allContentTokens)")
                let finalMessage = String(allContentTokens.joined())
                log("finalMessage: \(finalMessage)")
                
                // Compose full decoded response
                let decodedResponse = try AIRequest.buildResponse(from: decodedChunks)
                let validatedDecodedResponse = try AIRequest.validateResponse(decodedResult: decodedResponse)

                // TODO: need to come back here to support message struct
//                return .success((validatedDecodedResponse, response))
                fatalError()
            } catch {
                log("Could not get byte from bytes: \(error.localizedDescription)")
                return .failure(error)
            }
        }
    }
}

// Make these private methods on StitchAIManager
extension String {
    func removeDataPrefix() -> String {
        self.hasPrefix("data: ") ? String(self.dropFirst(6)) : self
    }
    
    func removeStepsPrefix() -> String {
        var str = self
        if let range = str.range(of: #"{"steps":["#) {
            str.removeSubrange(range)
            return str
        } else {
            return str
        }
    }
    
    // nil = could not retrieve `content` key's value
    func getContentToken() -> String? {
        
        guard let jsonStrAsData: Data = self
                // Remove the "data: " prefix OpenAI inserts
            .removeDataPrefix().data(using: .utf8) else {
            
            return nil
        }
        
        // Retrieve the token from the deeply-nested `content` key
        guard let valueForContentKey = try? jsonStrAsData.getContentKey() else {
            return nil
        }
        
        log("found valueForContentKey: \(valueForContentKey)")
        assertInDebug(valueForContentKey.count <= 1)
        return valueForContentKey.first
    }
    
    /// Try various trimmings of front and back characters of a string, to parse the string as a json of type T.
    /// Useful in cases where we're parsing a stream of tokens and each token may be e.g. ", {"
    func eagerlyParseAsT<T: Decodable>() -> T? {
        
        for trimFromBack in (0...4) {
            
            let backTrimmed = String(self.dropLast(trimFromBack))
            
            for trimFromFront in (0...4) {
                
                let backAndFrontTrimmed = String(backTrimmed.dropFirst(trimFromFront))
                
                if let data: Data = backAndFrontTrimmed.data(using: .utf8),
                   let step = try? JSONDecoder().decode(T.self, from: data) {
                    return step
                }
            } // for trimFromFront in ...
        } // for trimFromBack in ...
        
        return nil
    }
}


extension StitchAIRequestable {
    /*
     Iterate through the list of passed-in tokens,
     progressively building another list of tokens which can be turned into a string
     that can be parsed as a Step.
     
     If we find a Step, we return:
     `(the Step we found, the list of tokens starting with the token where we found the Step)`
     */
    // fka `streamDataHelper`
    static func decodeFromTokenStream(tokens: [String]) -> (Self.TokenDecodedResult, [String])? {
        
        // TODO: not needed, since we reset upon finding a Step anyway ?
        var tokensSoFar = [String]()
        
        for (tokenIndex, token) in tokens.enumerated() {
            
            tokensSoFar.append(token)
            
            let message: String = String(tokensSoFar.joined())
            // Always remove the steps prefix
                .removeStepsPrefix()
            
            if let result: Self.TokenDecodedResult = message.eagerlyParseAsT() {
                log("found decoded token: \(result)")
                let newTokens = tail(of: tokens, from: tokenIndex)
                // print("\n newMessage: \(String(newTokens.joined()))")
                return (result, newTokens)
            }
        } // for token in
        
        // Didn't find anything
        return nil
    }
}

func tail<T>(of list: [T], from index: Int) -> [T] {
    guard index < list.count else {
        return []
    }
    
    return Array(list[index...])
}

extension Data {
    func getContentKey() throws -> [String]? {
        
        let data = self
        
        guard let stream = try? JsonInputStream(data: data) else {
            return nil
        }
        
        let contentToken: JsonKey = .name("content")
        
        var contentStrings: [String] = []
        
        while let token: JsonToken = try stream.read() {
            switch token {
                
            case .string(contentToken, let value):
                // log("getContentKey: found string token: \(value)")
                contentStrings.append(value)
                
            case .bool(contentToken, let value):
                // log("getContentKey: found bool token: \(value)")
                contentStrings.append(value.description)
                
            case .number(contentToken, let .int(value)):
                // log("getContentKey: found number int token: \(value)")
                contentStrings.append(value.description)
                
            case .number(contentToken, let .double(value)):
                // log("getContentKey: found number double token: \(value)")
                contentStrings.append(value.description)
                
            case .number(contentToken, let .decimal(value)):
                // log("getContentKey: found number decimal token: \(value)")
                contentStrings.append(value.description)
                
            default:
                // log("getContentKey: some token other than string, bool, int, double or decimal: token: \(token)")
                continue
            }
        }
        
        // log("getContentKey: returning contentStrings: \(contentStrings)")
        return contentStrings
    }
}

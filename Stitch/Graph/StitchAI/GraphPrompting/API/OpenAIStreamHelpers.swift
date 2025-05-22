//
//  JsonStreamTest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/8/25.
//

import SwiftUI
import JsonStream
import SwiftyJSON

extension StitchAIManager {
    
    // TODO: streamData opens a stream; the stream sends us events (from the server) that we respond to
    
    // MARK: - Streaming helpers
    /// Perform an HTTP request and stream back the response, printing each chunk as it arrives.
    func streamData(for urlRequest: URLRequest,
                    graph: GraphState) async throws -> (Data, URLResponse, [Step]) {
        
        var accumulatedData = Data()
        var accumulatedSteps: [Step] = []
        var accumulatedString = ""
        
        // `bytes(for:)` returns an `AsyncSequence` of individual `UInt8`s
        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                
        var currentChunk: [UInt8] = []
                    
        // Tracks every token received, never reset
        var allContentTokens = [String]()
        
        // Tracks tokens; 'semi-reset' when we encounter a new step
        var contentTokensSinceLastStep = [String]()
        
        for try await byte in bytes {
            accumulatedData.append(byte)
            currentChunk.append(byte)
            
            guard byte == 10, !currentChunk.isEmpty else {
                continue
            }
                        
            if let chunkDataString = String(data: Data(currentChunk), encoding: .utf8),
               let contentToken = chunkDataString.getContentToken() {
                
                allContentTokens.append(contentToken)
                contentTokensSinceLastStep.append(contentToken)
                
                if let (newStep, newTokens) = parseStepFromTokenStream(tokens: contentTokensSinceLastStep) {
                    contentTokensSinceLastStep = newTokens
                    
                    DispatchQueue.main.async {
                        dispatch(ChunkProcessed(newStep: newStep))
                    }
                }
            }
            
            // Clear the current chunk
            currentChunk.removeAll(keepingCapacity: true)
            
        } // for byte in bytes
        
        log("allContentTokens: \(allContentTokens)")
        let finalMessage = String(allContentTokens.joined())
        log("finalMessage: \(finalMessage)")
                
        return (accumulatedData, response, accumulatedSteps)
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


/*
 Iterate through the list of passed-in tokens,
 progressively building another list of tokens which can be turned into a string
 that can be parsed as a Step.
 
 If we find a Step, we return:
    `(the Step we found, the list of tokens starting with the token where we found the Step)`
 */
// fka `streamDataHelper`
func parseStepFromTokenStream(tokens: [String]) -> (Step, [String])? {
        
    // TODO: not needed, since we reset upon finding a Step anyway ?
    var tokensSoFar = [String]()
        
    for (tokenIndex, token) in tokens.enumerated() {
        
        tokensSoFar.append(token)
        
        let message: String = String(tokensSoFar.joined())
        // Always remove the steps prefix
            .removeStepsPrefix()

        if let step: Step = message.eagerlyParseAsT() {
            log("found step: \(step)")
            let newTokens = tail(of: tokens, from: tokenIndex)
            // print("\n newMessage: \(String(newTokens.joined()))")
            return (step, newTokens)
        }
    } // for token in
    
    // Didn't find anything
    return nil
    
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

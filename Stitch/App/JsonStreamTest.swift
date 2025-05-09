//
//  JsonStreamTest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/8/25.
//

import SwiftUI
import JsonStream
import SwiftyJSON

//let countries = """
//[
//    {
//        "name": "United Kingdom",
//        "population": 68138484,
//        "density": 270.7,
//        "cities": [
//            {"name": "London", "isCapital": true},
//            {"name": "Liverpool", "isCapital": false}
//        ],
//        "monarch": "King Charles III"
//    },
//    {
//        "name": "United States",
//        "population": 333287557,
//        "density": 33.6,
//        "cities": [
//            {"name": "Washington, D.C", "isCapital": true},
//            {"name": "San Francisco", "isCapital": false}
//        ],
//        "monarch": null
//    }
//]
//""".data(using: .utf8)!


// WORKS!!
let countries = """
    {
        "id":"chatcmpl-BUi2EUZIRU49Vr27zit1mu5l7r8hq",
        "object":"chat.completion.chunk",
        "created":1746658810,
        "model":"ft:gpt-4o-2024-08-06:ve::BUXnDVxt",
        "service_tier":"default",
        "system_fingerprint":"fp_de53d86beb",
    
        "choices":[
            {
                "index":0,
                "delta":
                    {
                        "content": "set"
                    },
                "logprobs":null,
                "finish_reason":null 
            } 
        ]
    }
"""
    .data(using: .utf8)!

// "unexpected EOF" error with the below ?

//let countries = """
//[
//    {"id":"chatcmpl-BUi2EUZIRU49Vr27zit1mu5l7r8hq","object":"chat.completion.chunk","created":1746658810,"model":"ft:gpt-4o-2024-08-06:ve::BUXnDVxt","service_tier":"default","system_fingerprint":"fp_de53d86beb",
//       
//       "choices":[{"index":0,
//           "delta": 
//               {"content":"_type"},"logprobs":null,"finish_reason":null}]}
//
//
//   , {"id":"chatcmpl-BUi2EUZIRU49Vr27zit1mu5l7r8hq","object":"chat.completion.chunk","created":1746658810,"model":"ft:gpt-4o-2024-08-06:ve::BUXnDVxt","service_tier":"default","system_fingerprint":"fp_de53d86beb",
//       
//       "choices":[{"index":0,
//           "delta":
//               {"content":"\":\""},"logprobs":null,"finish_reason":null}]}
//
//
//   , {"id":"chatcmpl-BUi2EUZIRU49Vr27zit1mu5l7r8hq","object":"chat.completion.chunk","created":1746658810,"model":"ft:gpt-4o-2024-08-06:ve::BUXnDVxt","service_tier":"default","system_fingerprint":"fp_de53d86beb",
//       
//       "choices":[{"index":0,
//           "delta":
//               {"content":"set"},"logprobs":null,"finish_reason":null}]}
//
//
//   , {"id":"chatcmpl-BUi2EUZIRU49Vr27zit1mu5l7r8hq","object":"chat.completion.chunk","created":1746658810,"model":"ft:gpt-4o-2024-08-06:ve::BUXnDVxt","service_tier":"default","system_fingerprint":"fp_de53d86beb",
//
//       "choices":[{"index":0,
//           "delta":
//               {"content":"_input"},"logprobs":null,"finish_reason":null}]}
//]
//"""
//    .data(using: .utf8)!


let directoryURL: URL = FileManager.default.temporaryDirectory
let countriesURL: URL = directoryURL.appending(component: "countries.json")
let countriesPath: String = countriesURL.path(percentEncoded: false)


let chunk1 = """
 {"id":"chatcmpl-BUi2EUZIRU49Vr27zit1mu5l7r8hq","object":"chat.completion.chunk","created":1746658810,"model":"ft:gpt-4o-2024-08-06:ve::BUXnDVxt","service_tier":"default","system_fingerprint":"fp_de53d86beb",
    "choices":[{"index":0,
        "delta": 
            {"content":"_type"},"logprobs":null,"finish_reason":null}]}

"""
    .data(using: .utf8)!

let chunk2 = """
 {"id":"chatcmpl-BUi2EUZIRU49Vr27zit1mu5l7r8hq","object":"chat.completion.chunk","created":1746658810,"model":"ft:gpt-4o-2024-08-06:ve::BUXnDVxt","service_tier":"default","system_fingerprint":"fp_de53d86beb",    
    "choices":[{"index":0,
        "delta":
            {"content": ":"},"logprobs":null,"finish_reason":null}]}

"""
    .data(using: .utf8)!
// {"content":" ":"},"logprobs":null,"finish_reason":null}]}
// {"content":" ":Love!"},"logprobs":null,"finish_reason":null}]}

let chunk3 = """
 {"id":"chatcmpl-BUi2EUZIRU49Vr27zit1mu5l7r8hq","object":"chat.completion.chunk","created":1746658810,"model":"ft:gpt-4o-2024-08-06:ve::BUXnDVxt","service_tier":"default","system_fingerprint":"fp_de53d86beb",
    "choices":[{"index":0,
        "delta":
            {"content":"set"},"logprobs":null,"finish_reason":null}]}

"""
    .data(using: .utf8)!

let chunk4 = """
 {"id":"chatcmpl-BUi2EUZIRU49Vr27zit1mu5l7r8hq","object":"chat.completion.chunk","created":1746658810,"model":"ft:gpt-4o-2024-08-06:ve::BUXnDVxt","service_tier":"default","system_fingerprint":"fp_de53d86beb",
    "choices":[{"index":0,
        "delta":
            {"content":"_input"},"logprobs":null,"finish_reason":null}]}
"""
    .data(using: .utf8)!

let chunk5 = """
    {"content": ":"} 
"""
//    .data(using: .ascii)!
    .data(using: .utf8)!



let chunks = [chunk1, chunk2, chunk3, chunk4, chunk5]

struct JsonStreamTest: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .onTapGesture {
                log("TAPPED")
                
                var contentFromAllChunks = [[String]]()
                
                for chunk in chunks {
                    if let contentValue = try? getContentKey(chunk) {
                        log("getValueForContentKey: contentValue: \(contentValue)")
                        contentFromAllChunks.append(contentValue)
                    }
                }
                
                log("final contentFromAllChunks: \(contentFromAllChunks)")
                
                
                let messageProgress =  [[""], ["{\""], ["steps"], ["\":["], ["{\""], ["node"], ["_id"], ["\":\""], ["A"], ["1"], ["B"], ["2"], ["C"], ["3"], ["D"], ["4"], ["-E"], ["5"], ["F"], ["6"], ["-"], ["789"], ["0"], ["-"]]
                                        
                var message = messageProgress.megajoin()
                
                
                let toRemove = #"{"steps":["#
                if let range = message.range(of: toRemove) {
                    log("message was: \(message)")
                    message.removeSubrange(range)
                    log("message is now: \(message)")
                }
                
                
                let _message = messageProgress.megajoin()
                
                if let messageData = _message.data(using: .utf8) {
                    let stepsKey = try? getStepsKey(messageData)
                    log("getValueForContentKey: stepsKey: \(stepsKey)")
                }
                
            }
    }
    
    
    
    func getValueForContentKey() throws {
        let jis = try JsonInputStream(filePath: countriesPath)
        
        // For if the JSON has multiple `content` keys
        let path = jis.pathMatch(
            .name("choices"),
            .index(0),
            .name("delta"),
            .name("content")
        )
        
        log("path: \(path)")
        
        while let token = try jis.read() {
            switch token {
            case .string(.name("content"), let value):
                print("string: content: \(value)")
            case .number(.name("content"), let .int(value)):
                print("number: content: \(value)")
            default:
                continue
            }
        }
    }
    
    
    
    func example1a() throws {
        
        let jis = try JsonInputStream(filePath: countriesPath)
        
        for tokenResult in jis {
            switch tokenResult {
            case let .success(token):
                log("token: \(token)")
            case let .failure(error):
                //                throw error
                log("error: \(error)")
            }
        }
    }
    
    func example7() throws {
        let jis = try JsonInputStream(filePath: countriesPath)
        
        while let token = try jis.read() {
            switch token {
            case .string(.name("name"), let value) where jis.path.count == 2:
                print("country: \(value)")
            case .number(.name("population"), let .int(value)):
                print("population: \(value)")
            default:
                continue
            }
        }
    }
    
}



func getContentKey(_ data: Data) throws -> [String]? {
    
//    let dataAsString = String(data: data, encoding: .utf8)
//    log("getContentKey: called for \(dataAsString)")
    
    guard let stream = try? JsonInputStream(data: data) else {
        // log("getContentKey: could not get stream from data")
        return nil
    }
    
    // // For if the JSON has multiple `content` keys at various levels
    // let path = jis.pathMatch(.name("choices"), .index(0), .name("delta"), .name("content"))
    
    /*
     Questions:
     1. Should there only be *one* `content` key per chunk?
     2. Can the value change? e.g. be a string vs a number vs ...; and how do we combine those again later?
     ... try to get all strings, and combine those into a single string which we then parse as a json?
     */
    
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


func getStepsKey(_ data: Data) throws -> String? {
    guard let stream = try? JsonInputStream(data: data) else {
        log("getStepsKey: could not get stream from data")
        return nil
    }
    
    while let token: JsonToken = try stream.read() {
        switch token {
        case .string(.name("steps"), let value):
            // will
            log("getStepsKey: found string token: \(value)")
            return value
//        case .startArray(.name("steps")):
            
        default:
            log("getStepsKey: some token other than string, bool, int, double or decimal: token: \(token)")
            continue
        }
    }
    
    return nil
}


extension StitchAIManager {
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
            
        var allContentTokens = [[String]]()
        
        var contentTokensSinceLastStep = [[String]]()
        // var contentTokensSinceLastStep = [[String]]()
        
        for try await byte in bytes {
            accumulatedData.append(byte)
            currentChunk.append(byte)
            
            guard byte == 10, !currentChunk.isEmpty else {
                continue
            }
            
            let chunkData = Data(currentChunk)
            if let chunkDataString = String(data: chunkData, encoding: .utf8),
               let contentToken = getContentToken(chunkDataString: chunkDataString) {
                
                allContentTokens.append(contentToken)
                
                contentTokensSinceLastStep = streamDataHelper(
                    contentToken: contentToken,
                    contentTokensThisSession: contentTokensSinceLastStep)
            }
            
            // Clear the current chunk
            currentChunk.removeAll(keepingCapacity: true)
            
        } // for byte in bytes
        
        
//        log("DONE: allContentVals: \(allContentVals)")
////        let message = allContentVals.map { $0.joined() }.joined()
//        let message = allContentVals.megajoin()
//        log("final message: \(message)")
//        
//        if let parsedSteps = try? StreamingChunkProcessor.getStepsFromJoinedString(message: message) {
//            log("parsedSteps: \(parsedSteps)")
//            return (accumulatedData, response, parsedSteps)
//        } else {
//            log("could not parse steps")
//            return (accumulatedData, response, accumulatedSteps)
//        }
        
        return (accumulatedData, response, accumulatedSteps)
        
//        // Print any trailing bytes that weren't newline-terminated
//        if !currentChunk.isEmpty {
//            let chunkData = Data(currentChunk)
//            if let str = String(data: chunkData, encoding: .utf8) {
////                print("OpenAI Stream Chunk: \(str)")
//                // Add final chunk to accumulated string
//                accumulatedString += str
//                
//                // Try to parse any remaining accumulated JSON
//                if let steps = try? StreamingChunkProcessor.processChunk(accumulatedString) {
//                    print(" Final chunk actions:")
//                    steps.forEach { step in
//                        print("  → \(step.description)")
//                    }
//                    accumulatedSteps.append(contentsOf: steps)
//                }
//            }
//        }
        
//        return (accumulatedData, response, accumulatedSteps)
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
}


// nil = could not retrieve `content` key's value
func getContentToken(chunkDataString: String) -> [String]? {
    // Remove the "data: " prefix OpenAI inserts
    guard let jsonStrAsData: Data = chunkDataString.removeDataPrefix().data(using: .utf8) else {
        return nil
    }
    
    // Retrieve the token from the deeply-nested `content` key
    guard let valueForContentKey = try? getContentKey(jsonStrAsData) else {
        return nil
    }
    
    log("found valueForContentKey: \(valueForContentKey)")
    return valueForContentKey
}


func streamDataHelper(contentToken: [String],
                      // i.e. "since last discovered step"
                      contentTokensThisSession: [[String]]) -> [[String]] {
            
    var contentTokensThisSession = contentTokensThisSession
    
    contentTokensThisSession.append(contentToken)
    log("contentTokensThisSession is now: \(contentTokensThisSession)")
        
    // If we have enough tokens for a string that starts like `steps`,
    // then we can eagerly attempt to decode a step.
    // TODO: can use JsonInputStream's `.arrayStarts(.name("steps"))` ?
    let messageSoFar = contentTokensThisSession
        .megajoin()
        .removeStepsPrefix()
        
    log("messageSoFar: \(messageSoFar)")
    
    // TODO: handle cases where we have multiple actions received
    // TODO: really, only need to iterate through 3 or so characters? Meant to handle case where a contentToken was e.g. ", {" and so we have to remove more than just 1 char
    for number in (0...4) {
        var messageToEdit = messageSoFar
        messageToEdit = String(messageToEdit.dropLast(number))
        log("messageToEdit is now number \(number): \(messageToEdit)")
        
        guard let dataFromMessageSoFar: Data = messageToEdit.data(using: .utf8) else {
            continue
        }
        
        guard let step = try? JSONDecoder().decode(Step.self, from: dataFromMessageSoFar) else {
            continue
        }
        log("found step: \(step)")
        
        DispatchQueue.main.async {
            dispatch(ChunkProcessed(newStep: step))
        }
        
        // Return immediately if we found a step
        return .init()
    } // for number in ...
    
    return contentTokensThisSession
}

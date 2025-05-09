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
        log("getContentKey: could not get stream from data")
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
            log("getContentKey: found string token: \(value)")
            contentStrings.append(value)
            
        case .bool(contentToken, let value):
            log("getContentKey: found bool token: \(value)")
            contentStrings.append(value.description)
            
        case .number(contentToken, let .int(value)):
            log("getContentKey: found number int token: \(value)")
            contentStrings.append(value.description)
            
        case .number(contentToken, let .double(value)):
            log("getContentKey: found number double token: \(value)")
            contentStrings.append(value.description)
            
        case .number(contentToken, let .decimal(value)):
            log("getContentKey: found number decimal token: \(value)")
            contentStrings.append(value.description)
            
        default:
//            log("getContentKey: some token other than string, bool, int, double or decimal: token: \(token)")
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
        
        var contentTokensSinceLastDecodedStep = [[String]]()
   
        for try await byte in bytes {
            
            // Always add byte to current chunk
            currentChunk.append(byte)
            
            // Only attempt to parse if we've hit a new line
//            guard byte == 10 else {
//                continue
//            }
            
            
            
            
            
            // Print when we hit a newline, which typically delimits server-sent events.
            if byte == 10 { // '\n'
                if !currentChunk.isEmpty {
                    let chunkData = Data(currentChunk)
                    //if let str = String(data: chunkData, encoding: .utf8) {
                    
                    // Probably want to decode this as an object or dictionary, or json, and access keys
                    
                    let str = String(data: chunkData, encoding: .utf8)
                    log("OpenAI Stream Chunk: str: \(str)")
                    
                    if let str = str,
                       //                       let json = try? SwiftyJSON.JSON(data: chunkData) {
                       let json = parseJSON(str) {
                        
                        log("OpenAI Stream Chunk: json: \(json)")
                        jsons.append(json)
                        
                        let choices = json["choices"]
                        log("OpenAI Stream Chunk: choices: \(choices)")
                        
                        let delta = json["choices"]["delta"]
                        log("OpenAI Stream Chunk: delta: \(delta)")
                        
                        let content = json["choices"]["delta"]["content"].stringValue
                        log("OpenAI Stream Chunk: content: \(content)")
                        
                        allContentTokens.append(content)
                        
                    } else {
                        log("could not parse chunk")
                    }
                    
                    //                    if let str = JSON {
                    //
                    //                        print("OpenAI Stream Chunk: \(str)")
                    //                        // Add to accumulated string
                    //                        accumulatedString += str
                    //
                    //                        // Try to parse accumulated string if it looks like complete JSON
                    //                        // We look for closing braces/brackets to guess if JSON is complete
                    //                        if accumulatedString.contains("}") || accumulatedString.contains("]") {
                    //                            print("Attempting to parse accumulated JSON:")
                    //                            print(accumulatedString)
                    //                            if let steps = try? StreamingChunkProcessor.processChunk(accumulatedString) {
                    //                                print(" Successfully parsed actions:")
                    //                                steps.forEach { step in
                    //                                    print("  → \(step.description)")
                    //                                }
                    //                                accumulatedSteps.append(contentsOf: steps)
                    //                                // Clear accumulated string since we successfully parsed it
                    //                                accumulatedString = ""
                    //                            }
                    //                        } // if accumulated
                    //
                    //                    } // if let str
                    
                    //                    currentChunk.removeAll(keepingCapacity: true)
                }
            }
            
            
            
//            // Turn the chunk into a Data and then into a String
//            guard let chunkDataString = String(data: Data(currentChunk), encoding: .utf8) else {
//                log("could not turn currentChunkData into a string")
//                continue
//            }
//            log("OpenAI Stream Chunk: chunkDataString: \(chunkDataString)")
//            
//            // MARK: remove the `data: ` prefix
//            // Note: seems like OpenAI's streamed response prefixes with `data: `
//            let jsonString = chunkDataString.removeDataPrefix()
//            
//            // Remove
//            guard let jsonStrAsData: Data = jsonString.data(using: .utf8) else {
//                log("could not turn jsonString into data")
//                continue
//            }
//            
//            // Note: JsonInputStream cannot read the
//            guard let contentToken: [String] = try? getContentKey(jsonStrAsData) else {
//                log("could not get contentKey for jsonStringData")
//                continue
//            }
//            
//            log("found contentToken: \(contentToken)")
//            
//            allContentTokens.append(contentToken)
//            log("allContentTokens: \(allContentTokens)")
//            
//            contentTokensSinceLastDecodedStep.append(contentToken)
//            log("contentTokensSinceLastDecodedStep: \(contentTokensSinceLastDecodedStep)")
//            
//            // Prepare the "tokens since last successful decoding"
//            let contentTokensAsString = contentTokensSinceLastDecodedStep.megajoin().removeStepsArrayOpenPrefx()
//            log("contentTokensAsString: \(contentTokensAsString)")
//            
//            if let decodedStep: Step = contentTokensAsString.eagerlyAttemptStepDecoding() {
//                log("found decodedStep: \(decodedStep)")
//                DispatchQueue.main.async {
//                    dispatch(ChunkProcessed(newStep: decodedStep))
//                }
//                
//                // if we successfully decoded a step, reset the currentChunk and contentTokens
//                currentChunk.removeAll(keepingCapacity: true)
//                contentTokensSinceLastDecodedStep = .init()
//            } // if let decodedStep
            
        } // for try await byte in bytes
        
        log("DONE: allContentTokens: \(allContentTokens)")
        let message = allContentTokens.megajoin()
        log("final message: \(message)")
        
        if let parsedSteps = try? StreamingChunkProcessor.getStepsFromJoinedString(message: message) {
            log("parsedSteps: \(parsedSteps)")
            return (accumulatedData, response, parsedSteps)
        } else {
            log("could not parse steps")
            return (accumulatedData, response, accumulatedSteps)
        }
        
        
        
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


extension String {
    func removeDataPrefix() -> String {
        let str = self
        return str.hasPrefix("data: ") ? String(str.dropFirst(6)) : str
    }
    
    func removeStepsArrayOpenPrefx() -> String {
        var str = self
        let toRemove = #"{"steps":["#
        if let range = str.range(of: toRemove) {
            str.removeSubrange(range)
            return str
        } else {
            return str
        }
    }
    
    func eagerlyAttemptStepDecoding() -> Step? {
        // for varying lengths of tokens added
        for number in (0...6) {
            let str = String(self.dropLast(number))
            log("eagerlyAttemptStepDecoding: attempting to decode str: \(str)")
            if let data: Data = str.data(using: .utf8),
               let step: Step = try? JSONDecoder().decode(Step.self, from: data) {
                    log("step from message so far: \(step)")
                    return step
            } // if let
        } // for number in ...
        
        return nil
    }
}

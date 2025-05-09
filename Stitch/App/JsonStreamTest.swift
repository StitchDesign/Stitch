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
            log("getContentKey: some token other than string, bool, int, double or decimal: token: \(token)")
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
        
        var allContentVals = [[String]]()
        
        // this is every single little character;
        // whereas we only want to try to read the individual json objects;
        // but not sure if we can rely on e.g. `}` for determining what that bracket closed
                
        for try await byte in bytes {
            accumulatedData.append(byte)
            currentChunk.append(byte)
            
//            let byteData = Data(byte)
            let currentChunkData = Data(currentChunk)
            
            
//            let byteDataString = String(data: byteData, encoding: .utf8)
            let currentChunkDataString = String(data: currentChunkData, encoding: .utf8)
            
//            log("byteDataString: \(byteDataString)")
            log("currentChunkDataString: \(String(describing: currentChunkDataString))")
            
            if let contentVals = try? getContentKey(currentChunkData) {
                log("found contentVals: \(contentVals)")
                allContentVals.append(contentVals)
            }
        }
//
        
//        for try await byte in bytes {
//            accumulatedData.append(byte)
//            currentChunk.append(byte)
//            
//            // Print when we hit a newline, which typically delimits server-sent events.
//            if byte == 10 { // '\n'
//                if !currentChunk.isEmpty {
//                    let chunkData = Data(currentChunk)
//                    
//                    if let str = String(data: chunkData, encoding: .utf8) {
//
//                        // TODO: why or how is `data: ` getting prefixed here?
//                        
//                        // the data prefix is preventing us from recognizing the streamed-json object ?
//                        let jsonString = str.hasPrefix("data: ")
//                        ? String(str.dropFirst(6))
//                        : str
//                        
//                        print("OpenAI Stream Chunk, had newline character: \(str)")
//                        
//                        if let jsonStrAsData: Data = jsonString.data(using: .utf8),
//                           
//                            let contentVals = try? getContentKey(jsonStrAsData) {
//                            
//                            log("found contentVals: \(contentVals)")
//                            allContentVals.append(contentVals)
//                            log("allContentVals is now: \(allContentVals)")
//                            
//                            // If we can chop off the "{steps:[" part and turn
////                            allContentVals.megajoin().
//                            var messageSoFar = allContentVals.megajoin()
//                            
//                            // if we can remove the "steps" part:
//                            let toRemove = #"{"steps":["#
//                            if let range = messageSoFar.range(of: toRemove) {
//                                log("messageSoFar was: \(messageSoFar)")
//                                messageSoFar.removeSubrange(range)
//                                log("messageSoFar is now: \(messageSoFar)")
//
//                                
//                                for number in (0...10) {
//                                    var messageToEdit = messageSoFar
//                                    messageToEdit = String(messageToEdit.dropLast(number))
//                                    log("messageToEdit is now number \(number): \(messageToEdit)")
//                                    
//                                    if let dataFromMessageSoFar: Data = messageToEdit.data(using: .utf8) {
//                                        
//                                        if let responses: [Step] = try? JSONDecoder().decode([Step].self, from: dataFromMessageSoFar) {
//                                            log("responses from message so far: \(responses)")
//                                            DispatchQueue.main.async {
//                                                for response in responses {
//                                                    dispatch(ChunkProcessed(newStep: response))
//                                                }
//                                            }
//                                            // allContentVals = .init()
//                                            break
//                                        }
//                                        
//                                        if let response: Step = try? JSONDecoder().decode(Step.self, from: dataFromMessageSoFar) {
//                                            log("response from message so far: \(response)")
//                                            
//                                            let alreadySeen = await graph.streamedSteps.contains { $0 == response }
//                                            log("response from message so far: alreadySeen ?: \(alreadySeen)")
//                                            if !alreadySeen {
//                                                DispatchQueue.main.async {
//                                                    dispatch(ChunkProcessed(newStep: response))
//                                                }
//                                            }
//                                            
////                                            DispatchQueue.main.async {
////                                                dispatch(ChunkProcessed(newStep: response))
////                                            }
//                                            // allContentVals = .init()
//                                            break
//                                        }
//                                    }
//                                }
//                                
//                                
//                               
//                            }
//                            
//                            
//                        } else {
//                            log("could not get ContentKey from chunkData")
//                        }
//                    }
//                    
//                    currentChunk.removeAll(keepingCapacity: true)
//                }
//            }
//        }
        
        log("DONE: allContentVals: \(allContentVals)")
//        let message = allContentVals.map { $0.joined() }.joined()
        let message = allContentVals.megajoin()
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

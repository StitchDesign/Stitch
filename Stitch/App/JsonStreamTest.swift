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
                    if let contentValue = try? self.getContentKey(chunk) {
                        log("getValueForContentKey: contentValue: \(contentValue)")
                        contentFromAllChunks.append(contentValue)
                    }
                }
                
                log("final contentFromAllChunks: \(contentFromAllChunks)")
                
                
//                if let _ = try? countries.write(to: countriesURL) {
//                    log("wrote successfully")
//                    
////                    if let _ = try? self.example1a() {
////                        log("did example 1a successfully")
////                    }
////                    
////                    if let _ = try? self.example7() {
////                        log("did example 7 successfully")
////                    }
////                    
////                    if let _ = try? self.getValueForContentKey() {
////                    }
//                    
//                   
//                    
//                    
//                } else {
//                    log("could not write")
//                }
            }
    }
    
    static let contentToken: JsonKey = .name("content")
    
    func getContentKey(_ data: Data) throws -> [String]? {
        
        let dataAsString = String(data: data, encoding: .utf8)
        log("getContentKey: called for \(dataAsString)")
        
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
        
        var contentStrings: [String] = []
        
        while let token: JsonToken = try stream.read() {
            switch token {
                
            case .string(Self.contentToken, let value):
                log("getContentKey: found string token: \(value)")
                contentStrings.append(value)
                
            case .bool(Self.contentToken, let value):
                log("getContentKey: found bool token: \(value)")
                contentStrings.append(value.description)
                
            case .number(Self.contentToken, let .int(value)):
                log("getContentKey: found number int token: \(value)")
                contentStrings.append(value.description)
                
            case .number(Self.contentToken, let .double(value)):
                log("getContentKey: found number double token: \(value)")
                contentStrings.append(value.description)
                
            case .number(Self.contentToken, let .decimal(value)):
                log("getContentKey: found number decimal token: \(value)")
                contentStrings.append(value.description)
                
            default:
                log("getContentKey: some token other than string, bool, int, double or decimal")
                continue
            }
        }
        
        log("getContentKey: returning contentStrings: \(contentStrings)")
        return contentStrings
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

/*
 steps with actual data:
 
 makeRequest calls `streamData(URLRequest) -> (Data, URLResponse, [Step])`
 
 
 
 */

extension StitchAIManager {
    // MARK: - Streaming helpers
    /// Perform an HTTP request and stream back the response, printing each chunk as it arrives.
    func streamData(for urlRequest: URLRequest) async throws -> (Data, URLResponse, [Step]) {
        var accumulatedData = Data()
        var accumulatedSteps: [Step] = []
        var accumulatedString = ""
        
        // `bytes(for:)` returns an `AsyncSequence` of individual `UInt8`s
        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
        
        var currentChunk: [UInt8] = []
        
        for try await byte in bytes {
            accumulatedData.append(byte)
            currentChunk.append(byte)
            
            let chunkData = Data(currentChunk)
            
            // For debug
            let str = String(data: chunkData, encoding: .utf8)
            log("OpenAI Stream Chunk: str: \(str)")
            
            
            
            //            // Print when we hit a newline, which typically delimits server-sent events.
            //            if byte == 10 { // '\n'
            //                if !currentChunk.isEmpty {
            //                    let chunkData = Data(currentChunk)
            //                    //if let str = String(data: chunkData, encoding: .utf8) {
            //
            //                    // Probably want to decode this as an object or dictionary, or json, and access keys
            //
            //                    let str = String(data: chunkData, encoding: .utf8)
            //                    log("OpenAI Stream Chunk: str: \(str)")
            //
            //                    if let str = str,
            ////                       let json = try? SwiftyJSON.JSON(data: chunkData) {
            //                       let json = parseJSON(str) {
            //
            //                        log("OpenAI Stream Chunk: json: \(json)")
            //                        jsons.append(json)
            //
            //                        let choices = json["choices"]
            //                        log("OpenAI Stream Chunk: choices: \(choices)")
            //
            //                        let delta = json["choices"]["delta"]
            //                        log("OpenAI Stream Chunk: delta: \(delta)")
            //
            //                        let content = json["choices"]["delta"]["content"].stringValue
            //                        log("OpenAI Stream Chunk: content: \(content)")
            //
            //                        contentValuesOnly.append(content)
            //
            //                    } else {
            //                        log("could not parse chunk")
            //                    }
            //
            ////                    if let str = JSON {
            ////
            ////                        print("OpenAI Stream Chunk: \(str)")
            ////                        // Add to accumulated string
            ////                        accumulatedString += str
            ////
            ////                        // Try to parse accumulated string if it looks like complete JSON
            ////                        // We look for closing braces/brackets to guess if JSON is complete
            ////                        if accumulatedString.contains("}") || accumulatedString.contains("]") {
            ////                            print("Attempting to parse accumulated JSON:")
            ////                            print(accumulatedString)
            ////                            if let steps = try? StreamingChunkProcessor.processChunk(accumulatedString) {
            ////                                print(" Successfully parsed actions:")
            ////                                steps.forEach { step in
            ////                                    print("  → \(step.description)")
            ////                                }
            ////                                accumulatedSteps.append(contentsOf: steps)
            ////                                // Clear accumulated string since we successfully parsed it
            ////                                accumulatedString = ""
            ////                            }
            ////                        } // if accumulated
            ////
            ////                    } // if let str
            //
            ////                    currentChunk.removeAll(keepingCapacity: true)
            //                }
            //            }
        }
        
        // Print any trailing bytes that weren't newline-terminated
        if !currentChunk.isEmpty {
            let chunkData = Data(currentChunk)
            if let str = String(data: chunkData, encoding: .utf8) {
                print("OpenAI Stream Chunk: \(str)")
                // Add final chunk to accumulated string
                accumulatedString += str
                
                // Try to parse any remaining accumulated JSON
                if let steps = try? StreamingChunkProcessor.processChunk(accumulatedString) {
                    print(" Final chunk actions:")
                    steps.forEach { step in
                        print("  → \(step.description)")
                    }
                    accumulatedSteps.append(contentsOf: steps)
                }
            }
        }
        
        return (accumulatedData, response, accumulatedSteps)
    }
}

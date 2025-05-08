//
//  JsonStreamTest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/8/25.
//

import SwiftUI
import JsonStream

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

let directoryURL = FileManager.default.temporaryDirectory
let countriesURL = directoryURL.appending(component: "countries.json")
let countriesPath = countriesURL.path(percentEncoded: false)


struct JsonStreamTest: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .onTapGesture {
                log("TAPPED")
                if let _ = try? countries.write(to: countriesURL) {
                    log("wrote successfully")
                    
                    if let _ = try? self.example1a() {
                        log("did example 1a successfully")
                    }
                    
                    if let _ = try? self.example7() {
                        log("did example 7 successfully")
                    }
                    
                    if let _ = try? self.getValueForContentKey() {
                        log("did getValueForContentKey successfully")
                    }
                    
                } else {
                    log("could not write")
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
    
    
    func getValueForContentKey() throws {
        let jis = try JsonInputStream(filePath: countriesPath)
        
        let path = jis.pathMatch(
            .name("choices"), .index(0), .name("delta"), .name("content")
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
}


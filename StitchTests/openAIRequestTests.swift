//
//  openAIRequestTests.swift
//  StitchTests
//
//  Created by Nicholas Arner on 1/27/25.
//

import XCTest
import StitchSchemaKit
@testable import Stitch

class OpenAIRequestTests: XCTestCase {
#if STITCH_AI
    func testSecretsNotNil() {
        let secrets = try? Secrets()
        XCTAssertNotNil(secrets)
    }
#endif
    
    /// Tests conversions to and from decoded state. StitchAI sometimes uses different types, this ensures types are compatible.
    func testStitchAICodables() {
        for type in NodeType.allCases.filter({ $0 != .none && $0 != .anchorEntity }) {
//            if type == .none || type == .anchorEntity {
//                print("testStitchAICodables: skipping type: \(type)")
//                continue
//            }
            
            print("testStitchAICodables: testing type: \(type)")
          
            let portValue = type.defaultPortValue
            let valueCodable = portValue.anyCodable
            let portValueType = type.portValueTypeForStitchAI
            
            guard let encoding = try? getStitchEncoder().encode(valueCodable) else {
                XCTFail("Could not encode type \(type)")
                fatalError()
            }
            
            let jsonString = String(data: encoding, encoding: .utf8)
            print("encoding as json: \(jsonString)")
            
            guard let decoder = try? getStitchDecoder().decodeStitchAI(portValueType, data: encoding) else {
                XCTFail("Could not decode type \(type)")
                fatalError()
            }
            
//            do {
//                let encoding = try getStitchEncoder().encode(valueCodable)
//                
//                let jsonString = String(data: encoding, encoding: .utf8)
//                print("encoding as json: \(jsonString)")
//                
//               
//                
//                print("successfully decoded")
//                
//            } catch {
//                print("failed to encode type \(type), with error: \(error)")
////                XCTFail(error.localizedDescription)
//            }
            
            
        }
    }
}

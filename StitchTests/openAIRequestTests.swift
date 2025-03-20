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
//#if STITCH_AI
    func testSecretsNotNil() throws {
        let secrets = try Secrets()
        XCTAssertNotNil(secrets)
    }
//#endif
    
    /// Tests conversions to and from decoded state. StitchAI sometimes uses different types, this ensures types are compatible.
    func testStitchAICodables() {
        
        let types = NodeType.allCases.filter({
            $0 != .none
        })
        
        for type in types  {
            
            print("testStitchAICodables: testing type: \(type)")
            
            let portValue: PortValue = type.defaultPortValue
            let valueCodable = portValue.anyCodable
            let portValueType = type.portValueTypeForStitchAI
            
            guard let encoding: Data = try? getStitchEncoder().encode(valueCodable) else {
                XCTFail("Could not encode type \(type)")
                fatalError()
            }
            
            let jsonString = String(data: encoding, encoding: .utf8)
            print("encoding as json: \(jsonString)")
            
            guard let decoder = try? getStitchDecoder().decodeStitchAI(portValueType, data: encoding) else {
                XCTFail("Could not decode type \(type)")
                fatalError()
            }
        }
    }
}

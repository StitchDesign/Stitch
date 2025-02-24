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
        for type in NodeType.allCases.filter({
            $0 != .none
            
            // TODO: implement anchorEntity decoding
            && $0 != .anchorEntity
            
            // TODO: why does decoding interactionId fail in this test but it's just fine in atual app?
            && $0 != .interactionId
        }) {
            
            print("testStitchAICodables: testing type: \(type)")
          
            let portValue: PortValue = type.defaultPortValue
            let valueCodable: any Codable = portValue.anyCodable
            let portValueType: Decodable.Type = type.portValueTypeForStitchAI
            
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

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
    func testSecretsNotNil() {
        let secrets = try? Secrets()
        XCTAssertNotNil(secrets)
    }
    
    /// Tests conversions to and from decoded state. StitchAI sometimes uses different types, this ensures types are compatible.
    func testStitchAICodables() {
        for type in NodeType.allCases {
            guard type != .none else { continue }
            
            let portValue = type.defaultPortValue
            let valueCodable = portValue.anyCodable
            let portValueType = type.portValueTypeForStitchAI
            
            do {
                let encoding = try getStitchEncoder().encode(valueCodable)
                
//                let jsonString = String(data: encoding, encoding: .utf8)
//                print("Json test: \(jsonString)")
                
                let decoding = try getStitchDecoder()
                    .decodeStitchAI(portValueType,
                                    data: encoding)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }
}

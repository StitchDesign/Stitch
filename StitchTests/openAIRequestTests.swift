//
//  openAIRequestTests.swift
//  StitchTests
//
//  Created by Nicholas Arner on 1/27/25.
//

import XCTest
import StitchSchemaKit
@testable import Stitch

import SwiftyJSON

class OpenAIRequestTests: XCTestCase {
    func testSecretsNotNil() throws {
        do {
            let secrets = try Secrets()
            XCTAssertNotNil(secrets)
        } catch {
            let path = Secrets.getPath()!
            let contents = try! String(contentsOf: path, encoding: .utf8)
            XCTFail("testSecretsNotNil failed with error: \(error)\njson: \(contents)")
        }
    }
    
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

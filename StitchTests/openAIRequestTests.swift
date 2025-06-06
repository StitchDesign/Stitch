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
        
        let types = StitchAINodeType.allCases.filter({
            $0 != .none
        })
        
        for type in types  {
            let runtimeNodeType: NodeType
            let aiPortValue: CurrentStep.PortValue
            
            print("testStitchAICodables: testing type: \(type)")
            do {
                runtimeNodeType = try NodeTypeVersion
                    .migrate(entity: type,
                             version: CurrentStep.documentVersion)
            } catch {
                XCTFail("testStitchAICodables failure: unable to migrate type: \(type)\nWith error: \(error.localizedDescription)")
                return
            }
            
            let portValue = runtimeNodeType.defaultPortValue

            do {
                aiPortValue = try portValue.convert(to: CurrentStep.PortValue.self)
            } catch {
                XCTFail("testStitchAICodables failure: unable to convert PortValue: \(portValue)\nWith error: \(error.localizedDescription)")
                return
            }
            
            let portValueType = type.portValueTypeForStitchAI
            let valueCodable = aiPortValue.anyCodable
            
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

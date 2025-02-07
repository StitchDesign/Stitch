//
//  openAIRequestTests.swift
//  StitchTests
//
//  Created by Nicholas Arner on 1/27/25.
//

import XCTest
@testable import Stitch

class OpenAIRequestTests: XCTestCase {
    
    func testSecretsVariablesNotNil() {
        #if STITCH_AI
        XCTAssertNotNil(Secrets.openAIAPIKey)
        XCTAssertFalse(Secrets.openAIAPIKey.isEmpty)
        
        XCTAssertNotNil(Secrets.openAIModel)
        XCTAssertFalse(Secrets.openAIModel.isEmpty)
        #else
        XCTAssertNil(Secrets.openAIAPIKey)
        XCTAssertTrue(Secrets.openAIAPIKey.isEmpty)
        
        XCTAssertNil(Secrets.openAIModel)
        XCTAssertTrue(Secrets.openAIModel.isEmpty)
        #endif
    }
}

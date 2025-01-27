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
        XCTAssertNotNil(Secrets.openAIAPIKey)
        XCTAssertFalse(Secrets.openAIAPIKey.isEmpty)
        
        XCTAssertNotNil(Secrets.openAIModel)
        XCTAssertFalse(Secrets.openAIModel.isEmpty)
    }
}

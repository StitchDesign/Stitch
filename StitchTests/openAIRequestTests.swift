//
//  openAIRequestTests.swift
//  StitchTests
//
//  Created by Nicholas Arner on 1/27/25.
//

import XCTest
@testable import Stitch

class OpenAIRequestTests: XCTestCase {
    func testSecretsNotNil() {
        let secrets = try? Secrets()
        XCTAssertNotNil(secrets)
    }
}

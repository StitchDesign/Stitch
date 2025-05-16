//
//  StitchFileTests.swift
//  prototypeTests
//
//  Created by Elliot Boschwitz on 5/7/22.
//

import XCTest
@testable import Stitch

final class StitchFileTests: XCTestCase {
    @MainActor
    var mockStore = StitchStore()
    
    func testSampleProjectOpen() async throws {
        guard let projects = try? SampleProjectsList.getProjects() else {
            XCTFail("Sample projects couldn't be retrieved")
            return
        }
        
        for project in projects {
            try await importStitchSampleProject(sampleProjectURL: project.url,
                                                store: mockStore)
        }
    }
 }

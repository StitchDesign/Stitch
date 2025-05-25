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
    
    /// Ensures markdown descriptions encapsulate all information and don't contain extra definitions.
    func testNodeDescriptions() {
        NodeKind.allCases.forEach { nodeKind in
            let nodesNotDefined = NodeKind.allCases.filter { NodeDescriptions.forKind($0) == nil }
            XCTAssertTrue(nodesNotDefined.isEmpty)
            
            let allNodeTitles = NodeKind.allCases.map(\.defaultDisplayTitle)
            let allNodeTitlesSet = allNodeTitles.toSet
            
            // Ensure no duplicate names
            XCTAssertEqual(allNodeTitles.count, allNodeTitlesSet.count)
            
            let extraNodesInMap = NodeDescriptions.map.filter {
                !allNodeTitlesSet.contains($0.key)
            }
            
            // Ensures the markdown doesn't contain extra nodes not captured in schema
            XCTAssertTrue(extraNodesInMap.isEmpty)
        }
    }
 }

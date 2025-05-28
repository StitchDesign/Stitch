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
    func testDocDescriptions() {
        NodeKind.allCases.forEach { nodeKind in
            let docsNotDefined = StitchDocsRouter.allCases.filter { $0.description == nil }
            XCTAssertTrue(docsNotDefined.isEmpty)
            
            guard let docsForPatches = StitchDocsRouter.map.get(.patch)?.keys,
                  let docsForLayers = StitchDocsRouter.map.get(.layer)?.keys else {
                XCTFail("Some docs not found for nodes")
                return
            }
            
            
            // MARK: the below tests don't work because we don't take into account various sections (i.e. "Arithmetic) in Patches but remains useful with breakpoints

            //            let expectedPatchHeaders = Set(StitchDocsPatchRouter.allCases.map(\.headerLabel))
//            let actualPatchHeaders = Set(docsForPatches)
//            let unaccountedPatchHeaders = actualPatchHeaders.subtracting(expectedPatchHeaders)
//            
//            // All headers should be accounted for in routing
//            XCTAssertTrue(unaccountedPatchHeaders.isEmpty)
//            
//            // Ensure no duplicate names
//            XCTAssertEqual(StitchDocsPatchRouter.allCases.count, StitchDocsRouter.map.get(.patch)?.count)
//            
//            let expectedLayerHeaders = Set(StitchDocsLayerRouter.allCases.map(\.headerLabel))
//            let actualLayerHeaders = Set(docsForLayers)
//            let unaccountedLayerHeaders = actualLayerHeaders.subtracting(expectedLayerHeaders)
//            
//            // All headers should be accounted for in routing
//            XCTAssertTrue(unaccountedLayerHeaders.isEmpty)
//            
//            // Ensure no duplicate names
//            XCTAssertEqual(StitchDocsLayerRouter.allCases.count, StitchDocsRouter.map.get(.layer)?.count)
    }
 }

//
//  SchemaConversionTests.swift
//  prototypeTests
//
//  Created by Elliot Boschwitz on 8/17/21.
//

@testable import Stitch
import XCTest

// class SchemaConversionTests: XCTestCase {
//
//    func testGraphSchemaBuilder(graphState: GraphState) {
//        let graphSchema: GraphSchema = .from(graphState, GraphUIState())
//        let convertedGraphState: GraphState = .from(graphSchema)
//
//        // TODO: come up with a better way to test topological sort orders, since there can be multiple acceptable solutions.
//        // Also, majority of these tests are created from nodes-only,
//        // i.e. there are no edges between these test-state nodes and so a topo-order test is not helpful.
//
//        XCTAssertEqual(convertedGraphState.patchNodes, graphState.patchNodes)
//        XCTAssertEqual(convertedGraphState.layerNodes, graphState.layerNodes)
//        XCTAssertEqual(convertedGraphState.edges, graphState.edges)
//    }
//
// }

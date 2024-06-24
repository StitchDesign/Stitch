//
//  nodeTypeTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 6/8/23.
//

import XCTest
import StitchSchemaKit
@testable import Stitch

final class nodeTypeTests: XCTestCase {

    @MainActor
    func testPatchNodeUserVisibleType() throws {

        Patch.allCases.forEach { patch in
            let node = patch.createDefaultTestNode()

            // If the patch has non-empty lists of available node types,
            // ... but the created node has no node type,
            // then crash.
            if patch.availableNodeTypes != EmptyUVT.value {

                if !node.userVisibleType.isDefined {
                    print("error on patch: \(patch)")
                }

                XCTAssert(node.userVisibleType.isDefined)
            }
        }
    }
}

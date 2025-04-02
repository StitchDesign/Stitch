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
    func testNodeTypeChange() async throws {
        let document = await StitchDocumentViewModel.createTestFriendlyDocument()
        let node = try XCTUnwrap(document.nodeInserted(choice: .patch(.add)))
        
        let numberInputs = node.inputsObservers.allSatisfy { (input: InputNodeRowObserver) in
            input.allLoopedValues.allSatisfy { (value: PortValue) in
                value.getNumber.isDefined
            }
        }
                
        XCTAssertTrue(numberInputs)
                
        let _ = document.graph.nodeTypeChanged(nodeId: node.id,
                                               newNodeType: .size,
                                               activeIndex: document.activeIndex)
        
        let sizeInputs = node.inputsObservers.allSatisfy { (input: InputNodeRowObserver) in
            input.allLoopedValues.allSatisfy { (value: PortValue) in
                value.getSize.isDefined
            }
        }
                
        XCTAssertTrue(sizeInputs)
    }
    
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

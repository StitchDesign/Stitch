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

    @MainActor var store = StitchStore()
    
    @MainActor
    func testNodeTypeChange() throws {
        let document = StitchDocumentViewModel.createTestFriendlyDocument(store)
        let node = try XCTUnwrap(document.nodeInserted(choice: .patch(.add)))
        
        let numberInputs = node.inputsObservers.allSatisfy { (input: InputNodeRowObserver) in
            input.allLoopedValues.allSatisfy { (value: PortValue) in
                value.getNumber.isDefined
            }
        }
                
        XCTAssertTrue(numberInputs)
                
        let _ = document.graph.nodeTypeChanged(nodeId: node.id,
                                               newNodeType: .size,
                                               activeIndex: document.activeIndex,
                                               graphTime: document.graphStepState.graphTime)
        
        let sizeInputs = node.inputsObservers.allSatisfy { (input: InputNodeRowObserver) in
            input.allLoopedValues.allSatisfy { (value: PortValue) in
                value.getSize.isDefined
            }
        }
                
        XCTAssertTrue(sizeInputs)
    }
    
    @MainActor
    func testPatchNodeUserVisibleType() throws {

        let graph = GraphState()
        Patch.allCases.forEach { patch in
            let node = patch.createDefaultTestNode(graph: graph)

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

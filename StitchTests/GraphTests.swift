//
//  GraphTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 4/23/25.
//

import XCTest
@testable import Stitch

final class GraphTests: XCTestCase {
    
    @MainActor var store = StitchStore()
    
    // Cannot be async, so cannot be used to create a document
    @MainActor
    override func setUp() {
        self.store = StitchStore() // wipe the store
    }

    /*
     We treat graph open and graph reset the same: outputs are empty.
     
     Nodes' evals know how to provide themselves with default prevValues if the output is empty etc.
     
     Added as test due to regression where we stopped wiping outputs (which broke e.g. Counter node on graph reset) and did not catch it in QA.
     */
    @MainActor
    func testOutputsWipedOnGraphReset() throws {
        let document: StitchDocumentViewModel = .createTestFriendlyDocument(store)
        
        let counterNode = document.nodeInserted(choice: .patch(.counter))
        let loopOptionSwitchNode = document.nodeInserted(choice: .patch(.loopOptionSwitch))
                
        // Provide some non-zero value
        counterNode.outputsObservers.first!.updateOutputValues([.number(99)])
        loopOptionSwitchNode.outputsObservers.first!.updateOutputValues([.number(99)])
        
        // Confirm the output is non-zero
        XCTAssert(counterNode.outputs.first!.first!.getNumber == 99)
        XCTAssert(loopOptionSwitchNode.outputs.first!.first!.getNumber == 99)
        
        // Restart the prototype
        document.onPrototypeRestart(document: document)
        
        // Confirm the output is zero
        XCTAssert(counterNode.outputs.first!.first!.getNumber == 0)
        XCTAssert(loopOptionSwitchNode.outputs.first!.first!.getNumber == 0)
    }

}

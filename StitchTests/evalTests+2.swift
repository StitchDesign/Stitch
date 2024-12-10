//
//  evalTests+2.swift
//  prototypeTests
//
//  Created by Christian J Clampitt on 12/8/21.
//

import StitchSchemaKit
import XCTest
@testable import Stitch

class EvalTests2: XCTestCase {

    /*
     Test confirms that:
     1. we don't crash on node's eval
     2. we have expected node type

     Note: does NOT check whether label changes were correct; see e.g. pack node and unpack node type change tests for that.
     */
    //    func testCommonNodeTypeChange() throws {
    //
    //        Patch.allCases.forEach { patch in
    //            let node = patch.getFakePatchNode()
    //            let graphState = GraphState()
    //            var graphSchema = devDefaultGraphSchema()
    //            graphState.updatePatchNode(node)
    //            graphSchema.updateNode(node)
    //
    //            patch.availableNodeTypes.forEach({ nodeType in
    //
    //                let result = NodeTypeChangedAction(nodeId: node.id,
    //                                                   newNodeType: nodeType)
    //                    .handle(graphSchema: graphSchema,
    //                            graphState: graphState,
    //                            computedGraphState: .init(),
    //                            environment: .init())
    //
    //                graphSchema = result.state!
    //
    //                XCTAssert(node.userVisibleType.isDefined)
    //                XCTAssertEqual(node.userVisibleType, nodeType)
    //
    //                // Run the eval to confirm we don't crash
    //                let _ = node.calculatePatchNode(
    //                    // What data should we have in GraphState ?
    //                    graphSchema: graphSchema,
    //                    graphState: graphState,
    //                    computedGraphState: .init(),
    //                    environment: .init(),
    //                    mustFlow: true,
    //                    isGraphBuild: false)
    //            })
    //        }
    //    }
    //
    //    // Test that we always run nodes' evals
    //    func testCalculateGraphFromState() throws {
    //
    //        let loopNode = Patch.loop.defaultTestNode
    //
    //        let addNode = Patch.add.defaultTestNode
    //
    //        // update second input to be non-zero
    //        addNode.inputs[1] = [.number(2)]
    //
    //        let multiplyNode = Patch.multiply.defaultTestNode
    //
    //        let edges: Edges = [
    //            .init(from: .init(portId: 0, nodeId: loopNode.id),
    //                  to: .init(portId: 0, nodeId: addNode.id)),
    //            .init(from: .init(portId: 0, nodeId: addNode.id),
    //                  to: .init(portId: 0, nodeId: multiplyNode.id))
    //        ]
    //
    //        let graphState = GraphState()
    //        var graphSchema = devDefaultGraphSchema()
    //        graphSchema.updateNodes([loopNode, addNode, multiplyNode])
    //        graphSchema.connections = getConnections(from: edges)
    //        graphState.topologicalData = graphState.createTopologicalData(graphSchema)
    //
    //        // Update node view models
    //        graphState.visibleNodesViewModel
    //            .updateGraphSchemaData(graphSchema: graphSchema,
    //                                   activeIndex: .init(.zero))
    //
    //        // Look at outputs of the middle node: confirm that we have a loop and that the node's eval was run
    //        let _ = recalculateGraphFromState(graphSchema: graphSchema,
    //                                          graphState: graphState,
    //                                          computedGraphState: .init(),
    //                                          environment: .init())
    //
    //        let result = graphState.getPatchNode(id: addNode.id)!.outputs
    //
    //        let expected: PortValuesList = [[.number(2), .number(3), .number(4)]]
    //
    //        XCTAssertEqual(result, expected)
    //    }

    @MainActor
    func testProgressEvalNegativeZero() throws {

        let n1: PortValues = [.number(0)]
        let n2: PortValues = [.number(0)]
        let n3: PortValues = [.number(10)]

        let inputs: PortValuesList = [n1, n2, n3]

        let expectedOutput: PortValues = [.number(-0)]
        //        let expectedOutput: PortValues = [.number(0)]

        let result: PortValuesList = progressEval(
            inputs: inputs,
            outputs: [])

        // Swift doesn't distinguish between -0 and 0?
        // Treats both as satisfying equality?
        XCTAssertEqual(0, -0)

        XCTAssertEqual(result, [expectedOutput])
    }

    @MainActor
    func testProgressEvalNaN() throws {

        let n1: PortValues = [.number(0)]
        let n2: PortValues = [.number(0)]
        let n3: PortValues = [.number(0)]

        let inputs: PortValuesList = [n1, n2, n3]

        let expectedOutput: PortValues = [.number(0)]

        let result: PortValuesList = progressEval(
            inputs: inputs,
            outputs: [])

        XCTAssertEqual(result, [expectedOutput])
    }

    @MainActor
    func testProgressEvalInfinity() throws {

        let n1: PortValues = [.number(10)]
        let n2: PortValues = [.number(0)]
        let n3: PortValues = [.number(0)]

        let inputs: PortValuesList = [n1, n2, n3]

        let expectedOutput: PortValues = [.number(0)]

        let result: PortValuesList = progressEval(
            inputs: inputs,
            outputs: [])

        XCTAssertEqual(result, [expectedOutput])
    }

    func testLoopOverArrayEval() throws {
        let input: PortValues = [.json(emptyStitchJSONObject)]

        let resultOutputs: PortValuesList = loopOverArrayEval(
            inputs: [input],
            outputs: [])

        let outputIndexLoop = resultOutputs[0]
        let outputValuesLoop = resultOutputs[1]

        let expectedIndexLoop: PortValues = [.number(0)]
        let expectedValuesLoop: PortValues = [.json(emptyStitchJSONArray)]

        XCTAssertEqual(outputIndexLoop, expectedIndexLoop)
        XCTAssertEqual(outputValuesLoop, expectedValuesLoop)
    }
}

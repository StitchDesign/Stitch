//
//  inputEditTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 4/25/23.
//

import XCTest
@testable import Stitch

// final class inputEditTests: XCTestCase {
//
//    func testShapeCommandEdits() throws {
//
//        let nodeId = NodeId.fakeNodeId
//        let splitterNode = splitterPatchNode(nodeId: nodeId)
//        let graphState = GraphState()
//        var graphSchema = GraphSchema()
//
////        let state = ProjectState(
////            metadata: .fakeProjectMetadata,
////            graph: graphState)
//
//        graphState.updatePatchNode(splitterNode)
//
//        // Convert splitter to node type = .shapeCommand
//        // defaults to command type = .move
//
//
//        state.graph.updatePatchNode(state.graph.changeType(
//                                        for: splitterNode,
//                                        type: .shapeCommand,
//                                        graphTime: .zero,
//                                        mediaDict: .init()).first!)
//
//        // Don't have "change command type via dropdown" logic for SC-type splitters yet
//        //        let scSplitter = state.graph.getPatchNode(id: nodeId)!
//
//        let input = InputCoordinate(portId: 0,
//                                    nodeId: nodeId)
//
//        let values = InputEdited(fieldValue: .string("22"),
//                                 fieldIndex: 1,
//                                 coordinate: input,
//                                 isCommitting: false)
//            .handle(state: state, environment: .init())
//            .state!
//            .graph.getInputValues(coordinate: input)
//
//        XCTAssertEqual(ShapeCommand.moveTo(point: .init(x: 22, y: 0)),
//                       values?.first?.shapeCommand)
//    }
//
//    func testMultifieldEdits() throws {
//
//        let graphState = GraphState()
//        let layerNode = ovalLayerNode(id: .fakeNodeId,
//                                      size: .init(width: 4, height: 8))
//
//        let state = ProjectState(
//            metadata: .fakeProjectMetadata,
//            graph: graphState)
//
//        graphState.updateLayerNode(layerNode)
//
//        let updatedState = InputEdited(fieldValue: .string("6"),
//                                       fieldIndex: 0,
//                                       coordinate: .init(portId: Layer.oval.sizeIndex,
//                                                         nodeId: layerNode.id),
//                                       isCommitting: false)
//            .handle(state: state,
//                    environment: .init())
//            .state!
//
//        let actualSizeInput = updatedState.graph.fullLayerNodesAsList.first!.getSizeInput().first!
//        let expectedSizeInput = LayerSize(width: 6, height: 8)
//
//        XCTAssertEqual(actualSizeInput, expectedSizeInput)
//
//        let coordinate = InputCoordinate(portId: Layer.oval.sizeIndex,
//                                         nodeId: layerNode.id)
//        let updatedState2 = InputEdited(fieldValue: .string("9"),
//                                        fieldIndex: 1,
//                                        coordinate: coordinate,
//                                        isCommitting: false)
//            .handle(state: updatedState,
//                    environment: .init())
//            .state!
//
//        let actualSizeInput2 = updatedState2.graph.fullLayerNodesAsList.first!.getSizeInput().first!
//        let expectedSizeInput2 = LayerSize(width: 6, height: 9)
//
//        XCTAssertEqual(actualSizeInput2, expectedSizeInput2)
//
//        // Editing height field again
//        let updatedState3 = InputEdited(fieldValue: .string("90"), // edited 9 -> 90
//                                        fieldIndex: 1,
//                                        coordinate: coordinate,
//                                        isCommitting: false)
//            .handle(state: updatedState2,
//                    environment: .init())
//            .state!
//
//        let actualSizeInput3 = updatedState3.graph.fullLayerNodesAsList.first!.getSizeInput().first!
//        let expectedSizeInput3 = LayerSize(width: 6, height: 90)
//
//        XCTAssertEqual(actualSizeInput3, expectedSizeInput3)
//
//    }
// }

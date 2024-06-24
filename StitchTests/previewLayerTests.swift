//
//  previewLayerTests.swift
//  StitchTests
//
//  Created by Elliot Boschwitz on 5/19/23.
//

import XCTest
@testable import Stitch

// // TODO: REVISIT AFTER PREVIEW WINDOW LOGIC FINALIZED
// class PreviewLayerTests: XCTestCase {
//    var previewLayersViewModel = PreviewLayersViewModel(allLayers: [])
//
//    override func setUp() async throws {
//        // Reset preview layers after each test
//        self.previewLayersViewModel = .init(allLayers: [])
//    }
//
//    func testTextLayerEvalArrayInequalLoops() throws {
//        var projectState = ProjectState()
//
//        // text loop
//        let textLoop: PortValues = [
//            .string("0"),
//            .string("1"),
//            .string("2")
//        ]
//
//        let firstPosition = CGSize(width: 0.0, height: 0.0)
//        let secondPosition = CGSize(width: 50.0, height: 50.0)
//
//        // position loop
//        let positionLoop: PortValues = [
//            .position(firstPosition),
//            .position(secondPosition)
//        ]
//
//        var textLayerNode = textLayerNode(id: .init())
//        guard let positionIndex = Layer.text.positionIndex else {
//            XCTFail("No position index found.")
//            return
//        }
//
//        textLayerNode.inputs[0] = textLoop
//        textLayerNode.inputs[positionIndex] = positionLoop
//        projectState.graph.updateLayerNode(textLayerNode)
//        let result = projectState.recalculateFullGraph(environment: StitchEnvironment())
//        projectState = result.toProjectResponse(projectState).state!
//
//        self.previewLayersViewModel.regenerateLayers(from: projectState.graph)
//        let views = self.previewLayersViewModel.allLayers
//        let textLayerViewModels: [TextLayerViewModel] = views.compactMap { viewData in
//            switch viewData {
//            case .nongroup(let id):
//                switch self.previewLayersViewModel.viewModelMap.get(id) {
//                case .text(let viewModel):
//                    return viewModel
//                default:
//                    XCTFail("Text view model expected but not found.")
//                    return nil
//                }
//            default:
//                XCTFail("Non-group view data expected but not found.")
//                return nil
//            }
//        }
//
//        // CONFIRM THAT AS MANY VIEWS WERE CREATED AS LONGEST LOOP COUNT
//        // textLoop is longest loop here
//        XCTAssertEqual(views.count, textLoop.count)
//
//        // CONFIRM THAT VIEWS HAVE APPROPRIATE VALUES
//        XCTAssertEqual(textLayerViewModels[0].text.getString, "0")
//        XCTAssertEqual(textLayerViewModels[1].text.getString, "1")
//        XCTAssertEqual(textLayerViewModels[2].text.getString, "2")
//
//        XCTAssertEqual(textLayerViewModels[0].position.getPosition, firstPosition)
//        XCTAssertEqual(textLayerViewModels[1].position.getPosition, secondPosition)
//        XCTAssertEqual(textLayerViewModels[2].position.getPosition, firstPosition)
//    }
//
//    func testSidebarOrderSimple() throws {
//        var state = ProjectState()
//
//        // Simple case: no loops, no groups etc.
//
//        let nodes: LayerNodes = [
//            textLayerNode(id: TestIds._1, previewLayerZIndices: [20]),
//            textLayerNode(id: TestIds._2, previewLayerZIndices: [20])
//        ]
//
//        nodes.forEach {
//            state.graph.updateLayerNode($0)
//        }
//
//        // trigger layer state update
//        state = state.updateAfterLayerNodesChanged()
//        self.previewLayersViewModel.regenerateLayers(from: state.graph)
//
//        let previewState = self.previewLayersViewModel.allLayers
//
//        let expectedCount = 2
//
//        // In order of high to low z-index
//        let expectedCoords = [
//            PreviewCoordinate(layerNodeId: TestIds._2.asLayerNodeId,
//                              loopIndex: 0),
//            PreviewCoordinate(layerNodeId: TestIds._1.asLayerNodeId,
//                              loopIndex: 0)
//        ]
//
//        XCTAssertEqual(expectedCount, previewState.count)
//        XCTAssertEqual(expectedCoords, previewState.map {$0.id})
//    }
//
//    func testSidebarAbsoluteOrder() throws {
//        var state = ProjectState()
//
//        /*
//         If sidebar and layers are:
//         Layer A, with manually edited z-input = 2
//         Layer B, with manually edited z-input = 3
//         Layer C, with manually edited z-input = 3
//
//         Then preview window z-ordering is:
//         Layer B
//         Layer C
//         Layer A
//         */
//
//        // more complicated case
//        let nodes: LayerNodes = [
//            textLayerNode(id: TestIds._1, previewLayerZIndices: [20]),
//            textLayerNode(id: TestIds._2, previewLayerZIndices: [10, 20, 30]),
//            textLayerNode(id: TestIds._3, previewLayerZIndices: [10, 20, 30])
//        ]
//
//        nodes.forEach {
//            state.graph.updateLayerNode($0)
//        }
//
//        // trigger layer state update
//        state = state.updateAfterLayerNodesChanged()
//        self.previewLayersViewModel.regenerateLayers(from: state.graph)
//
//        let result = self.previewLayersViewModel.allLayers
//
//        let expectedCount = 7
//
//        /*
//         Layer 2 index 2 (z = 30)
//         Layer 3 index 2 (z = 30)
//         Layer 1 index 0 (z = 20)
//         Layer 2 index 1 (z = 20)
//         Layer 3 index 1 (z = 20)
//         Layer 2 index 0 (z = 10)
//         Layer 3 index 0 (z = 10)
//         */
//
//        // In order of high to low z-index
//        let expectedCoords = [
//            PreviewCoordinate(layerNodeId: TestIds._3.asLayerNodeId,
//                              loopIndex: 0),
//            PreviewCoordinate(layerNodeId: TestIds._2.asLayerNodeId,
//                              loopIndex: 0),
//            PreviewCoordinate(layerNodeId: TestIds._3.asLayerNodeId,
//                              loopIndex: 1),
//            PreviewCoordinate(layerNodeId: TestIds._2.asLayerNodeId,
//                              loopIndex: 1),
//            PreviewCoordinate(layerNodeId: TestIds._1.asLayerNodeId,
//                              loopIndex: 0),
//            PreviewCoordinate(layerNodeId: TestIds._3.asLayerNodeId,
//                              loopIndex: 2),
//            PreviewCoordinate(layerNodeId: TestIds._2.asLayerNodeId,
//                              loopIndex: 2)
//        ]
//
//        XCTAssertEqual(expectedCount,
//                       result.count)
//
//        XCTAssertEqual(expectedCoords,
//                       result.map {$0.id})
//
//    }
// }

//
//  groupTests.swift
//  prototypeTests
//
//  Created by Christian J Clampitt on 7/29/21.
//

import XCTest
@testable import Stitch
import SwiftUI

// TODO: REVISIT THESE AFTER WE'RE ABLE TO EDIT INPUTS ETC. AND WE'VE QA'D THIS LOGIC IN APP

//// LayerGroup tests
// class GroupTests: XCTestCase {
//
//    func testCalculatingGroupLayerSizeAndPosition() throws {
//
//        let activeIndex = ActiveIndex(0)
//        let size0 = LayerSize(width: 200, height: 200)
//        let child0 = rectangleLayerNode(id: TestIds._0, size: size0)
//
//        let size1 = LayerSize(width: 200, height: 300)
//        let child1 = rectangleLayerNode(id: TestIds._1, size: size1)
//
//        let result = getLayerGroupFit(
//            [child0],
//            parentSize: DEFAULT_PREVIEW_SIZE,
//            activeIndex: activeIndex)
//
//        // For case of single selected child node
//        XCTAssertEqual(result.size, size0)
//        XCTAssertEqual(result.position, .zero)
//
//        let result2 = getLayerGroupFit(
//            [child0, child1],
//            parentSize: DEFAULT_PREVIEW_SIZE,
//            activeIndex: activeIndex)
//
//        XCTAssertEqual(result2.size, size1)
//        XCTAssertEqual(result2.position, .zero)
//
//        let child2 = rectangleLayerNode(id: TestIds._2,
//                                        size: size0,
//                                        layerPosition: CGSize(width: 0, height: 100))
//
//        let result3 = getLayerGroupFit(
//            [child0, child2],
//            parentSize: DEFAULT_PREVIEW_SIZE,
//            activeIndex: activeIndex)
//
//        // child0 and child2 are same size, but the latter has been moved south by 100,
//        // so the group's size should be 200x300
//        XCTAssertEqual(result3.size, size1)
//        XCTAssertEqual(result3.position, .zero)
//    }
//
//    // When a child has negative y position ("north")
//    // and/or negative x position ("west"),
//    // we must also modify the positions of parent and the children.
//    // The parent's position (ie the position of the newly created group)
//    // has those x,y magnitudes SUBTRACTED,
//    // and each child's position has those x,y magnitudes ADDED.
//    func testNorthAndWestChild() throws {
//
//        let activeIndex = ActiveIndex(0)
//
//        let size = LayerSize(width: 300, height: 300)
//
//        // green
//        let child0 = rectangleLayerNode(id: TestIds._0,
//                                        size: size,
//                                        layerPosition: CGSize(width: -200, height: -200))
//
//        // blue
//        let child1 = rectangleLayerNode(id: TestIds._1,
//                                        size: size,
//                                        layerPosition: .zero)
//
//        // red
//        let child2 = rectangleLayerNode(id: TestIds._2,
//                                        size: size,
//                                        layerPosition: CGSize(width: 200, height: 200))
//
//        let children = [child0, child1, child2]
//
//        // Create graph state
//        let state = GraphState()
//        children.forEach {
//            state.updateLayerNode($0)
//        }
//
//        // needs to also return updated nodes
//        let result = getLayerGroupFit(
//            [child0, child1, child2],
//            parentSize: DEFAULT_PREVIEW_SIZE,
//            activeIndex: activeIndex)
//
//        let updatedChildrenInputs = adjustGroupChildrenToLayerFit(result,
//                                                                  children,
//                                                                  state.nodeInputs)
//        state.nodeInputs = updatedChildrenInputs
//        let updatedChildren = children.compactMap { state.getLayerNode(id: $0.id) }
//
//        XCTAssertEqual(result.size,
//                       LayerSize(width: 700, height: 700))
//        XCTAssertEqual(result.position,
//                       StitchPosition(width: -200, height: -200))
//        XCTAssertEqual(result.childAdjustment,
//                       StitchPosition(width: 200, height: 200))
//
//        // and then each child layer node should have different positions
//        // all the positions shifted by +200,+200
//        zip(children, updatedChildren).forEach { oldChild, updatedChild in
//            XCTAssertEqual(
//                updatedChild.layerPosition(activeIndex),
//                updatePosition(position: oldChild.layerPosition(activeIndex),
//                               offset: result.childAdjustment))
//        }
//    }
//
//    func testScaledChild() throws {
//        let activeIndex = ActiveIndex(0)
//        let size = LayerSize(width: 300, height: 300)
//        let child = rectangleLayerNode(id: TestIds._0,
//                                       size: size,
//                                       layerScale: 2)
//
//        let result = getLayerGroupFit([child],
//                                      parentSize: DEFAULT_PREVIEW_SIZE,
//                                      activeIndex: activeIndex)
//
//        XCTAssertEqual(result.size,
//                       LayerSize(width: 600, height: 600))
//        XCTAssertEqual(result.position, .zero)
//        XCTAssertEqual(result.childAdjustment, .zero)
//    }
//
//    // test "100%" layer sizees (eg "50%" width, "10% height)
//    func testParentPercentageChild() throws {
//        let activeIndex = ActiveIndex(0)
//        let parentWidth: CGFloat = 500
//        let parentHeight: CGFloat = 600
//        let parentSize = CGSize(width: parentWidth,
//                                height: parentHeight)
//
//        let size: LayerSize = LayerSize(width: .parentPercent(50),
//                                        height: .parentPercent(10))
//
//        let child = rectangleLayerNode(id: TestIds._0, size: size)
//
//        let result = getLayerGroupFit([child],
//                                      parentSize: parentSize,
//                                      activeIndex: activeIndex)
//
//        XCTAssertEqual(result.size,
//                       LayerSize(width: parentWidth * 0.5,
//                                 height: parentHeight * 0.1))
//        XCTAssertEqual(result.position, .zero)
//        XCTAssertEqual(result.childAdjustment, .zero)
//    }
//
//    // test "100%" layer sizees (eg "50%" width, "10% height)
//    func testNestedParentPercentageChild() throws {
//        let activeIndex = ActiveIndex(0)
//        let parentWidth: CGFloat = 500
//        let parentHeight: CGFloat = 600
//        let parentSize = CGSize(width: parentWidth,
//                                height: parentHeight)
//
//        let size: LayerSize = LayerSize(width: .parentPercent(50),
//                                        height: .parentPercent(10))
//
//        let child = rectangleLayerNode(id: TestIds._0, size: size)
//
//        let result = getLayerGroupFit([child],
//                                      parentSize: parentSize,
//                                      activeIndex: activeIndex)
//
//        XCTAssertEqual(result.size,
//                       LayerSize(width: parentWidth * 0.5,
//                                 height: parentHeight * 0.1))
//        XCTAssertEqual(result.position, .zero)
//        XCTAssertEqual(result.childAdjustment, .zero)
//    }
//
//    // for when activeIndex is outside input loop's range
//    func testActiveIndex() throws {
//        //        let activeIndex = 0
//
//        let parentWidth: CGFloat = 500
//        let parentHeight: CGFloat = 600
//        let parentSize = CGSize(width: parentWidth,
//                                height: parentHeight)
//
//        let size0: LayerSize = LayerSize(width: 0, height: 0)
//        let size1: LayerSize = LayerSize(width: 100, height: 100)
//
//        let child = rectangleLayerNode(
//            id: TestIds._0,
//            layerSizeLoop: [size0, size1])
//
//        let result = getLayerGroupFit(
//            [child],
//            parentSize: parentSize,
//            // since loop indices are [0, 1]
//            // an active index of 3 wraps around to be 1 again
//            activeIndex: ActiveIndex(3))
//
//        XCTAssertEqual(result.size,
//                       LayerSize(width: 100, height: 100))
//        XCTAssertEqual(result.position, .zero)
//        XCTAssertEqual(result.childAdjustment, .zero)
//
//        let result2 = getLayerGroupFit(
//            [child],
//            parentSize: parentSize,
//            activeIndex: ActiveIndex(2))
//
//        XCTAssertEqual(result2.size,
//                       LayerSize(width: 0, height: 0))
//        XCTAssertEqual(result2.position, .zero)
//        XCTAssertEqual(result2.childAdjustment, .zero)
//
//    }
//
//    func testGetParentSize() throws {
//
//        let parent = groupLayerNode(id: TestIds._0,
//                                    size: LayerSize(width: 400,
//                                                    height: 400))
//
//        let parent1 = groupLayerNode(id: TestIds._1,
//                                     size: LayerSize(width: .parentPercent(50),
//                                                     height: 400))
//
//        let child = rectangleLayerNode(id: TestIds._2,
//                                       size: LayerSize(width: .parentPercent(50),
//                                                       height: 400))
//
//        let groups: SidebarGroupsDict = [
//            asLayerNodeId(TestIds._0): [asLayerNodeId(TestIds._1)],
//            asLayerNodeId(TestIds._1): [asLayerNodeId(TestIds._2)]
//        ]
//
//        let sidebarState = SidebarState(sidebarGroups: groups)
//        let state = GraphState(sidebarState: sidebarState)
//        state.updateLayerNode(parent)
//        state.updateLayerNode(parent1)
//        state.updateLayerNode(child)
//
//        let parentSize = getParentSizeForSelectedNodes(
//            [child],
//            state,
//            groups,
//            previewWindowSize: DEFAULT_PREVIEW_SIZE,
//            activeIndex: ActiveIndex(0))
//
//        let expectedParentSize = CGSize(width: 200, height: 400)
//        XCTAssertEqual(expectedParentSize, parentSize)
//    }
//
//    func testGetParentSizeSimpleCase() throws {
//
//        let parent = groupLayerNode(id: TestIds._0,
//                                    size: LayerSize(width: 400,
//                                                    height: 400))
//
//        let parent1 = groupLayerNode(id: TestIds._1,
//                                     size: LayerSize(width: 400,
//                                                     height: 400))
//
//        let child = rectangleLayerNode(id: TestIds._2,
//                                       size: LayerSize(width: .parentPercent(50),
//                                                       height: 400))
//
//        let groups: SidebarGroupsDict = [
//            asLayerNodeId(TestIds._0): [asLayerNodeId(TestIds._1)],
//            asLayerNodeId(TestIds._1): [asLayerNodeId(TestIds._2)]
//        ]
//
//        let sidebarState = SidebarState(sidebarGroups: groups)
//        let state = GraphState(sidebarState: sidebarState)
//        state.updateLayerNode(parent)
//        state.updateLayerNode(parent1)
//        state.updateLayerNode(child)
//
//        // parent size of child will be 400
//        let parentSize = getParentSizeForSelectedNodes(
//            [child],
//            state,
//            groups,
//            previewWindowSize: DEFAULT_PREVIEW_SIZE,
//            activeIndex: ActiveIndex(0))
//
//        let expectedParentSize = CGSize(width: 400, height: 400)
//
//        XCTAssertEqual(expectedParentSize, parentSize)
//    }
//
//    func testGetParentSizeCustomPreviewWindow() throws {
//
//        let parent1 = groupLayerNode(id: TestIds._1,
//                                     size: LayerSize(width: .parentPercent(50),
//                                                     height: 400))
//
//        let child = rectangleLayerNode(id: TestIds._2,
//                                       size: LayerSize(width: .parentPercent(50),
//                                                       height: 400))
//
//        let groups: SidebarGroupsDict = [
//            asLayerNodeId(TestIds._1): [asLayerNodeId(TestIds._2)]
//        ]
//
//        let sidebarState = SidebarState(sidebarGroups: groups)
//        let state = GraphState(sidebarState: sidebarState)
//        state.updateLayerNode(parent1)
//        state.updateLayerNode(child)
//
//        // custom preview window size:
//        // iPhone 13 size
//        let previewWindowSize = CGSize(width: 390, height: 844)
//
//        // parent size of child will be 400
//        let parentSize = getParentSizeForSelectedNodes(
//            [child],
//            state,
//            groups,
//            previewWindowSize: previewWindowSize,
//            activeIndex: ActiveIndex(0))
//
//        let expectedParentSize = CGSize(width: 390 * 0.5 * 0.5,
//                                        height: 400)
//
//        XCTAssertEqual(expectedParentSize, parentSize)
//    }
//
//    // TODO:
//    // test non-left alignments; see notes
//    // test non-0 active-index
//
// }

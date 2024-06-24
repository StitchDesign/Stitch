//
//  sidebarTests.swift
//  prototypeTests
//
//  Created by Christian J Clampitt on 11/1/21.
//

import XCTest
import OrderedCollections
import StitchSchemaKit
@testable import Stitch

let testId1 = LayerNodeId(TestIds._1)
let testId2 = LayerNodeId(TestIds._2)
let testId3 = LayerNodeId(TestIds._3)
let testId4 = LayerNodeId(TestIds._4)
let testId5 = LayerNodeId(TestIds._5)
let testId6 = LayerNodeId(TestIds._6)
let testId7 = LayerNodeId(TestIds._7)
let testId8 = LayerNodeId(TestIds._8)
let testId9 = LayerNodeId(TestIds._9)

// class SidebarTests: XCTestCase {
//    let mockEnvironment = StitchEnvironment()
//
//    func testSidebarGroupCreation() throws {
//
//        // When we create a sidebar group, the
//        let nodes: LayerNodes = [
//            textLayerNode(id: TestIds._2),
//            groupLayerNode(id: TestIds._1),
//            groupLayerNode(id: TestIds._3)
//        ]
//
//        let expectedChildren = [
//            TestIds._2.asLayerNodeId,
//            TestIds._1.asLayerNodeId,
//            TestIds._3.asLayerNodeId
//        ]
//
//        var graphSchema = GraphSchema()
//        graphSchema.updateNodes(nodes)
//
//        // All three layer nodes are selected
//        let sidebarState = SidebarState(selectionState: .init(primary: .init(arrayLiteral: TestIds._2.asLayerNodeId, TestIds._1.asLayerNodeId, TestIds._3.asLayerNodeId)))
//
//        graphSchema.sidebarState = sidebarState
//
//        // graphSchema = // .getTestState(nodes, existingState: graphSchema)
//
//        //        let appState = AppState(
//        //            currentProject: ProjectState(
//        //                metadata: .init(name: "Fake Project"),
//        //                graph: graphSchema
//        //            )
//        //        )
//
//        let result = SidebarGroupCreated()
//            .handle(graphSchema: graphSchema,
//                    graphState: .init(),
//                    computedGraphState: .init(),
//                    environment: mockEnvironment)
//
//        //            .handle(state: appState,
//        //                    environment: mockEnvironment)
//        //            .state!
//
//        //        let createdGroup = result.currentProject!.graph.sidebarState.sidebarGroups
//        let createdGroup = result.state!.sidebarState.sidebarGroups
//        print("createdGroup: \(createdGroup)")
//        XCTAssert(createdGroup.values.first.isDefined)
//
//        XCTAssertEqual(createdGroup.values.first,
//                       expectedChildren)
//
//    }
//
//    func testSidebarItemOuterNestedGroupDeletion() throws {
//        // what happens when we delete a nested group
//        let nodes: LayerNodes = [
//            groupLayerNode(id: TestIds._1),
//            textLayerNode(id: TestIds._2),
//            groupLayerNode(id: TestIds._3),
//            rectangleLayerNode(id: TestIds._4),
//            visualMediaLayerNode(id: TestIds._5, layer: .image, media: nil)
//        ]
//
//        var graphSchema = GraphSchema()
//        graphSchema.updateNodes(nodes)
//
//        let groups: SidebarGroupsDict = [
//            LayerNodeId(TestIds._1): [LayerNodeId(TestIds._2), LayerNodeId(TestIds._3)],
//            LayerNodeId(TestIds._3): [LayerNodeId(TestIds._4)]
//        ]
//
//        //        graphSchema.sidebarState.sidebarGroups = groups
//
//        //        let expectedNodes: LayerNodesDict = [
//        let expectedNodes: LayerNodes = [
//            visualMediaLayerNode(id: TestIds._5,
//                                 layer: .image,
//                                 media: nil)
//        ]
//
//        let expectedIds: IdList = expectedNodes.map(\.id)
//
//        let expectedGroups: SidebarGroupsDict = [:]
//
//        // outer nested group selected
//        let selectionState = SidebarSelectionState(primary: Set([LayerNodeId(TestIds._1)]))
//
//        graphSchema.sidebarState = SidebarState(
//            items: asSidebarItems(
//                groups: groups,
//                //                layerNodes: state.layerNodes.toLayerNodesForSidebarDict),
//                layerNodes: graphSchema.layerNodesForSidebar()),
//            selectionState: selectionState,
//            sidebarGroups: groups
//        )
//
//        // test the logic prior to
//        graphSchema = SidebarSelectedItemsDeleted() // .handle(state: state)
//            .handle(graphSchema: graphSchema,
//                    graphState: .init(),
//                    computedGraphState: .init())
//            .state!
//
//        XCTAssertEqual(graphSchema.sidebarState.sidebarGroups, expectedGroups)
//
//        XCTAssertEqual(graphSchema.layerNodeIds, expectedIds)
//
//        print("testSidebarItemDeletion: Done...")
//
//    }
//
//    func testSidebarItemInnerNestedGroupDeletion() throws {
//        // what happens when we delete a nested group
//        let nodes = [
//            TestIds._1: groupLayerNode(id: TestIds._1).schema,
//            TestIds._2: textLayerNode(id: TestIds._2).schema,
//            TestIds._3: groupLayerNode(id: TestIds._3).schema,
//            TestIds._4: rectangleLayerNode(id: TestIds._4).schema,
//            TestIds._5: visualMediaLayerNode(id: TestIds._5, layer: .image, media: nil).schema
//        ]
//
//        var graphSchema = GraphSchema()
//        graphSchema.updateNodes(nodes)
//
//        let groups: SidebarGroupsDict = [
//            testId1: [testId2, testId3],
//            testId3: [testId4]
//        ]
//
//        let expectedNodes = [
//            TestIds._1: groupLayerNode(id: TestIds._1).schema,
//            TestIds._2: textLayerNode(id: TestIds._2).schema,
//            TestIds._5: visualMediaLayerNode(id: TestIds._5, layer: .image, media: nil).schema
//        ]
//
//        let expectedIds = expectedNodes.map(\.key).toSet
//
//        let expectedGroups: SidebarGroupsDict = [
//            testId1: [testId2]
//        ]
//
//        // outer nested group selected
//        let selectionState = SidebarSelectionState(primary: Set([testId3]))
//
//        graphSchema.sidebarState = SidebarState(
//            items: asSidebarItems(groups: groups,
//                                  layerNodes: graphSchema.layerNodesForSidebar()),
//            selectionState: selectionState,
//            sidebarGroups: groups
//        )
//
//        //        let state = GraphState(sidebarState: sidebar, layerNodes: nodes)
//
//        // test the logic prior to
//        graphSchema = SidebarSelectedItemsDeleted() // .handle(state: state)
//            .handle(graphSchema: graphSchema,
//                    graphState: .empty,
//                    computedGraphState: .init())
//            .state!
//
//        XCTAssertEqual(graphSchema.sidebarState.sidebarGroups, expectedGroups)
//
//        XCTAssertEqual(graphSchema.layerNodeIdsSet, expectedIds)
//    }
//
//    func testSidebarOuterNestedGroupUncreated() throws {
//        // what happens when we uncreate the outer group of a nested group
//        let nodes: LayerNodes = [
//            groupLayerNode(id: TestIds._1),
//            textLayerNode(id: TestIds._2),
//            groupLayerNode(id: TestIds._3),
//            rectangleLayerNode(id: TestIds._4),
//            visualMediaLayerNode(id: TestIds._5, layer: .image, media: nil)
//        ]
//
//        let groups: SidebarGroupsDict = [
//            LayerNodeId(TestIds._1): [
//                LayerNodeId(TestIds._2),
//                LayerNodeId(TestIds._3)
//            ],
//            LayerNodeId(TestIds._3): [
//                LayerNodeId(TestIds._4)
//            ]
//        ]
//
//        // the layer nodes should not change,
//        // except for the outer layer-group being gone
//        let expectedNodes: LayerNodes = [
//            textLayerNode(id: TestIds._2),
//            groupLayerNode(id: TestIds._3),
//            rectangleLayerNode(id: TestIds._4),
//            visualMediaLayerNode(id: TestIds._5, layer: .image, media: nil)
//        ]
//
//        let expectedIds: IdList = expectedNodes.map(\.id)
//
//        // Now there's only one group, the original inner nested group
//        let expectedGroups: SidebarGroupsDict = [
//            LayerNodeId(TestIds._3): [
//                LayerNodeId(TestIds._4)
//            ]
//        ]
//
//        //        var state = ProjectState(graph: GraphState.getTestState(nodes))
//        var graphSchema = GraphSchema()
//        graphSchema.updateNodes(nodes)
//
//        // When a layer group is uncreated,
//        // make sure that any edges coming into the layer group are removed.
//        graphSchema = NodeCreatedAction(choice: .patch(.add))
//            .handle(graphSchema: graphSchema,
//                    graphState: .init(),
//                    computedGraphState: .init(),
//                    environment: .init())
//            //            .handle(state: state, environment: .init())
//            .state!
//
//        let addNode = graphSchema.findNodes(for: .add).first!
//
//        //        let result = edgeAdded(
//        //            state: state,
//        let result = edgeAdded(
//            graphSchema: graphSchema,
//            graphState: .init(),
//            computedGraph: .init(),
//            environment: .init(),
//            // Edge from add node's output to layer group's position input
//            edge: PortEdge.init(
//                from: addNode.firstOutputCoordinate!,
//                to: .init(portId: 0, nodeId: TestIds._1)))
//
//        graphSchema = result.state
//
//        let sidebar = SidebarState(
//            items: asSidebarItems(groups: groups,
//                                  layerNodes: graphSchema.layerNodesForSidebar()),
//            sidebarGroups: groups
//        )
//
//        graphSchema.sidebarState = sidebar
//
//        // Use the actual event that selects the sidebar item;
//        // so that you get all the relevant changes re: primarily vs secondarily selecting an item.
//        graphSchema = SidebarItemSelected(id: LayerNodeId(TestIds._1)) // .handle(state: state.graph)
//            .handle(graphSchema: graphSchema,
//                    graphState: .init(),
//                    computedGraphState: .init())
//            .state!
//
//        graphSchema = SidebarGroupUncreated() // .handle(state: state).state!
//            .handle(graphSchema: graphSchema,
//                    graphState: .empty,
//                    computedGraphState: .init())
//            .state!
//
//        XCTAssertEqual(graphSchema.sidebarState.sidebarGroups,
//                       expectedGroups)
//
//        XCTAssertEqual(graphSchema.layerNodeIds,
//                       expectedIds)
//
//        // We should have removed the edge from Add node to GroupLayer node
//        XCTAssertEqual(graphSchema.connections, .init())
//
//        log("testSidebarOuterNestedGroupUncreated: Done...")
//
//    }
//
//    func testSidebarGroupDuplication() throws {
//        // when a group is duplicated,
//        // must recursively copy both actual layer nodes as well as grouping dict data
//
//        let nodes: LayerNodes = [
//            groupLayerNode(id: testId1.id),
//            textLayerNode(id: testId2.id),
//            visualMediaLayerNode(id: testId5.id, layer: .image, media: nil)
//        ]
//
//        let groups: SidebarGroupsDict = [
//            testId1: [testId2]
//        ]
//
//        // TODO: insert duplicated group right after
//
//        // When duplicating a group,
//        // the new group must came after the last descendent of the original group;
//        // ... but the order of the rest of the ids (ie the copied-over children)
//        // don't actually matter;
//        // only the copied children's order in a sidebar group childList matters.
//        let selectionState = SidebarSelectionState(primary: Set([testId1]))
//
//        //        var state = devDefaultProject()
//        //        state.graph = GraphState.getTestState(nodes)
//
//        var graphSchema = GraphSchema()
//        graphSchema.updateNodes(nodes)
//
//        graphSchema.sidebarState = SidebarState(
//            items: asSidebarItems(
//                groups: groups,
//                layerNodes: graphSchema.layerNodesForSidebar()),
//            selectionState: selectionState,
//            sidebarGroups: groups
//        )
//
//        graphSchema = SidebarSelectedItemsDuplicated()
//            //            .handle(state: state)
//            .handle(graphSchema: graphSchema, graphState: .empty, computedGraphState: .init())
//            .state!
//
//        // Can't test entire groups, since ids will be different
//        //        XCTAssertEqual(result.sidebarState.sidebarGroups,
//        //                       expectedGroups)
//
//        // Test that we have a second group with the same number of children as the original group:
//        XCTAssert(graphSchema.sidebarState.sidebarGroups.keys.count == 2)
//
//        // Copied layer group should have different id
//        XCTAssert(graphSchema.sidebarState.sidebarGroups.keys.last! != testId1)
//
//        // Copied layer group should have only one child
//        XCTAssert(graphSchema.sidebarState.sidebarGroups.values.last!.count == 1)
//        // ... whose id is not the same as the original group's child.
//        XCTAssert(graphSchema.sidebarState.sidebarGroups.values.last!.first! != testId2)
//
//        let originalGroupIndex: Int = graphSchema.layerNodeSchemas.firstIndex { $0.layerNodeId == testId1 }!
//
//        let copiedGroupIndex: Int = graphSchema.layerNodeSchemas.firstIndex { $0.isGroupLayer && $0.layerNodeId != testId1}!
//
//        log("testSidebarGroupDuplication: originalGroupIndex: \(originalGroupIndex)")
//        log("testSidebarGroupDuplication: copiedGroupIndex: \(copiedGroupIndex)")
//
//        XCTAssertTrue(copiedGroupIndex > originalGroupIndex)
//    }
//
//    func testSidebarLargeGroupDuplication() throws {
//
//        // When a group is duplicated,
//        // must recursively copy both actual layer nodes as well as grouping dict data
//        let nodes: LayerNodes = [
//            groupLayerNode(id: TestIds._1),
//            textLayerNode(id: TestIds._2),
//            groupLayerNode(id: TestIds._3),
//            rectangleLayerNode(id: TestIds._4),
//            visualMediaLayerNode(id: TestIds._5, layer: .image, media: nil)
//        ]
//
//        var graphSchema = GraphSchema()
//        graphSchema.updateNodes(nodes)
//
//        let groups: SidebarGroupsDict =  [
//            testId1: [testId2, testId3], // the group we'll duplicate
//            testId3: [testId4]
//        ]
//
//        let selectionState = SidebarSelectionState(primary: Set([testId1]))
//
//        graphSchema.sidebarState = SidebarState(
//            items: asSidebarItems(
//                groups: groups,
//                layerNodes: graphSchema.layerNodesForSidebar()),
//            selectionState: selectionState,
//            sidebarGroups: groups
//        )
//
//        graphSchema = SidebarSelectedItemsDuplicated()
//            .handle(graphSchema: graphSchema,
//                    graphState: .empty,
//                    computedGraphState: .init())
//            .state!
//
//        //        XCTAssertEqual(result2.sidebarState.sidebarGroups,
//        //                       expectedGroups)
//
//        // Confirm that original groups remain
//        XCTAssert(Array(graphSchema.sidebarState.sidebarGroups.keys.dropLast(2)) == Array(groups.keys))
//        XCTAssert(Array(graphSchema.sidebarState.sidebarGroups.values.dropLast(2)) == Array(groups.values))
//
//        // Confirm that two new groups were added
//        XCTAssert(graphSchema.sidebarState.sidebarGroups.keys.count == 4)
//
//        log("testSidebarLargeGroupDuplication: graphSchema.sidebarState.sidebarGroups.values: \(graphSchema.sidebarState.sidebarGroups.values)")
//
//        // TODO: revisit why this order is incorrect in the test; but seems correct in actual QA of graph
//        //        // Confirm that the 2nd-to-last group has two children
//        //        XCTAssert(graphSchema.sidebarState.sidebarGroups.values.dropLast().last!.count == 2)
//        //
//        //        // and that the last group has one child
//        //        XCTAssert(graphSchema.sidebarState.sidebarGroups.values.last!.count == 1)
//
//        // Confirm that
//
//        //        XCTAssertEqual(result2.layerNodes.map(\.key), expectedIds)
//
//        let originalGroupIndex: Int = graphSchema.layerNodeSchemas.firstIndex { $0.layerNodeId == testId1 }!
//        //        let copiedGroupIndex: Int = result2.layerNodes.values.firstIndex { $0.layerNodeId == testId6 }!
//
//        let copiedGroupIndex: Int = graphSchema.layerNodeSchemas.firstIndex { $0.isGroupLayer && $0.layerNodeId != testId1 }!
//
//        log("testSidebarLargeGroupDuplication: originalGroupIndex: \(originalGroupIndex)")
//        log("testSidebarLargeGroupDuplication: copiedGroupIndex: \(copiedGroupIndex)")
//
//        XCTAssertTrue(copiedGroupIndex > originalGroupIndex)
//
//        print("Done...")
//    }
//
//    func testSidebarGroupChildDuplication() throws {
//        // when a child in a group is duplicated,
//        // we must insert that copied-child into the same group
//
//        let nodes = [
//            testId1.id: groupLayerNode(id: testId1.id).schema,
//            testId2.id: textLayerNode(id: testId2.id).schema,
//            testId5.id: visualMediaLayerNode(id: testId5.id, layer: .image, media: nil).schema
//        ]
//
//        var graphSchema = GraphSchema()
//        graphSchema.updateNodes(nodes)
//
//        // duplicate the child of a group;
//        // child should be added to same group
//        let selectionState = SidebarSelectionState(primary: Set([testId2]))
//
//        let groups: SidebarGroupsDict = [
//            testId1: [testId2]
//        ]
//
//        graphSchema.sidebarState = SidebarState(
//            items: asSidebarItems(
//                groups: groups,
//                layerNodes: graphSchema.layerNodesForSidebar()),
//            selectionState: selectionState,
//            sidebarGroups: groups
//        )
//
//        graphSchema = SidebarSelectedItemsDuplicated()
//            .handle(graphSchema: graphSchema,
//                    graphState: .empty,
//                    computedGraphState: .init())
//            .state!
//
//        let duplicatedLayer = graphSchema.layerNodeSchemas.first(where: {
//            $0.id != testId1.id
//                && $0.id != testId2.id
//                && $0.id != testId5.id
//        })
//
//        // TODO: insert duplicated group right after
//        let expectedNodes = [
//            testId1.id: groupLayerNode(id: testId1.id).schema,
//            testId2.id: textLayerNode(id: testId2.id).schema,
//            //            testId6.id: textLayerNode(id: testId6.id),
//
//            testId5.id: visualMediaLayerNode(id: testId5.id, layer: .image, media: nil).schema
//        ]
//
//        let expectedGroups: SidebarGroupsDict = [
//            testId1: [testId2, duplicatedLayer!.layerNodeId]
//        ]
//
//        XCTAssertEqual(graphSchema.sidebarState.sidebarGroups,
//                       expectedGroups)
//
//        XCTAssertEqual(graphSchema.sidebarState.sidebarGroups,
//                       expectedGroups)
//
//        // There should be two children in the layer group now
//        XCTAssert(graphSchema.sidebarState.sidebarGroups.values.first!.count == 2)
//
//        let nodeId1Index = graphSchema.layerNodeIds.firstIndex(of: testId1.id)!
//        let nodeId2Index = graphSchema.layerNodeIds.firstIndex(of: testId2.id)!
//        let nodeId5Index = graphSchema.layerNodeIds.firstIndex(of: testId5.id)!
//
//        // Layer Node 5 should still come AFTER the original Layer Nodes
//        XCTAssert(nodeId1Index < nodeId5Index)
//        XCTAssert(nodeId2Index < nodeId5Index)
//        XCTAssert(nodeId1Index < nodeId2Index)
//
//        // Duplicated node should be second-to-last
//        // TODO: is this true?
//        XCTAssert(graphSchema.layerNodeSchemas.dropLast().last!.id != testId5.id)
//    }
// }

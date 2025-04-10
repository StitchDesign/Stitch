//
//  nodeUIGroupingTests.swift
//  prototypeTests
//
//  Created by Christian J Clampitt on 11/4/21.
//

import XCTest
@testable import Stitch
@testable import StitchSchemaKit

// https://stackoverflow.com/questions/20998788/failing-a-xctestcase-with-assert-without-the-test-continuing-to-run-but-without
extension XCTestCase {
    /// Like `XCTFail(...)` but aborts the test.
    func XCTAbortTest(_ message: String = "",
                      file: StaticString = #file, line: UInt = #line
                     ) -> Never {
        self.continueAfterFailure = false
        XCTFail(message, file: file, line: line)
        fatalError("never reached")
    }
}

class GroupNodeTests: XCTestCase {
    
    /// Simple GroupNode with two Add nodes inside; no incoming/outgoing edges or splitters.
    @MainActor
    static func createSimpleGroupNode() async -> (StitchDocumentViewModel, NodeViewModel) {
        let document = await StitchDocumentViewModel.createTestFriendlyDocument()
        let graphState = document.graph

        graphState.documentDelegate = document
        
        // Create two Add nodes
        guard let node1 = document.nodeInserted(choice: .patch(.add)),
              let node2 = document.nodeInserted(choice: .patch(.add)),
              let canvasNode1 = node1.patchCanvasItem,
              let canvasNode2 = node2.patchCanvasItem else {
//            XCTAbortTest()
            fatalError("failed to create Add nodes")
        }
                
        // Freshly created nodes should have no parent
        XCTAssert(canvasNode1.parentGroupNodeId == nil)
        XCTAssert(canvasNode2.parentGroupNodeId == nil)
                
        // Select the nodes
        graphState.selectCanvasItem(canvasNode1.id)
        graphState.selectCanvasItem(canvasNode2.id)
            
        // Create the group
        let _ = await document.createGroup(isComponent: false)
        
        XCTAssertEqual(graphState.groupNodes.keys.count, 1)
        
        guard let groupNode = graphState.groupNodes.values.first else {
//            XCTAbortTest()
            fatalError("did not have Group Node")
        }
                
        // Nodes should now have the recently created group node as a parent
        XCTAssert(canvasNode1.parentGroupNodeId == groupNode.id)
        XCTAssert(canvasNode2.parentGroupNodeId == groupNode.id)
        
        let nodesInGroup = graphState.nodes.values.filter { $0.patchCanvasItem?.parentGroupNodeId == groupNode.id }
        
        // There should only be two nodes in the group; no splitters etc.
        XCTAssertEqual(nodesInGroup.count, 2)
        
        return (document, groupNode)
    }
    
    @MainActor
    func testSimpleGroupNodeCreation() async throws {
        // MARK: SIMPLE NODE UI GROUP -- TWO ADD NODES, NO INCOMING OR OUTGOING EDGES
        let _ = await Self.createSimpleGroupNode()
    }
    
    @MainActor
    func testSimpleGroupNodeDuplication() async throws {
        let (document, groupNode) = await Self.createSimpleGroupNode()
//        let graphState = document.graph
        let groupNodeId = groupNode.id
        
        guard let canvasItem = groupNode.patchCanvasItem else {
            XCTFail()
            fatalError()
        }
                
        document.visibleGraph.selectCanvasItem(canvasItem.id)
        
        // Make sure only one node is selected
        // TODO: fix after changing "selecting group node = selecting its splitters as well"
        XCTAssertEqual(document.visibleGraph.selectedCanvasItems.count, 1)
        XCTAssertEqual(document.visibleGraph.selectedCanvasItems.first!, canvasItem.id)
                
        document.duplicateShortcutKeyPressed()
        
        XCTAssertEqual(document.visibleGraph.groupNodes.keys.count, 2)
        
        guard let otherGroupNodeId = document.visibleGraph.groupNodes.keys.first(where: { $0 != groupNodeId }) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(document.visibleGraph.nodes.values.filter { $0.patchCanvasItem?.parentGroupNodeId == groupNodeId }.count, 2)
        XCTAssertEqual(document.visibleGraph.nodes.values.filter { $0.patchCanvasItem?.parentGroupNodeId == otherGroupNodeId }.count, 2)
    }
}

// // TODO: REVISIT THESE TESTS ONCE NODE GROUPING LOGIC UPDATED
// class NodeUIGroupingTests: XCTestCase {
//    let mockEnvironment = StitchEnvironment()
//
//    func testCreateGroup() throws {
//
//        /*
//         Simple case:
//         - all nodes selected,
//         - no external incoming or outgoing connections
//         - we create a parent node
//         */
//
//        let nodes: PatchNodesDict = [
//            TestIds._1: splitterPatchNode(nodeId: TestIds._1).schema,
//            TestIds._2: splitterPatchNode(nodeId: TestIds._2).schema,
//            TestIds._3: addPatchNode(nodeId: TestIds._3).schema
//        ]
//
//        let selectedNodes = IdSet([TestIds._1, TestIds._2, TestIds._3])
//
//        let selection = GraphUISelectionState(selectedNodes: selectedNodes)
//
//        let uiState = StitchDocumentViewModel(selection: selection)
//
//        let graphState = GraphState(patchNodes: nodes)
//
//        let project = ProjectState(
//            metadata: ProjectMetadata(name: devDefaultProjectName()),
//            graph: graphState,
//            graphUI: uiState)
//
//        // Expect: a new group input and output node to have been created
//
//        // Since there are no connections to the original nodes that comprise the parent,
//        // the created parent node has no inputs or outputs.
//        let expectedNodes: PatchNodesDict = [
//            TestIds._1: splitterPatchNode(nodeId: TestIds._1).schema,
//            TestIds._2: splitterPatchNode(nodeId: TestIds._2).schema,
//            TestIds._3: addPatchNode(nodeId: TestIds._3).schema
//        ]
//
//        let result = GroupNodeCreatedEvent()
//            .handle(state: project, environment: mockEnvironment)
//            .state!
//
//        let createdGroupNodeId = result.graph.groupNodesState.keys.first!
//
//        // Confirm that only the newly created GroupNode is selected
//        XCTAssertEqual(result.graphUI.selection.selectedNodes,
//                       IdSet([createdGroupNodeId.id]))
//
//        // confirm that we have the expected ids
//        XCTAssertEqual(Set(result.graph.patchNodes.map(\.key)),
//                       Set(expectedNodes.map(\.key)))
//
//        // Should only have created one node
//        XCTAssert(result.graph.groupNodesState.keys.count == 1)
//
//        // Should have no layer nodes
//        XCTAssert(result.graph.groupNodesState.values.first!.layerNodes == IdSet())
//
//        // Should have these specific patch nodes
//        XCTAssert(result.graph.groupNodesState.values.first!.patchNodes == selectedNodes)
//    }
//
//    func testCreateAndUncreateParentWithExternalEdges() throws {
//
//        // MARK: PART 1: CREATE A GROUP
//
//        /*
//         Simple case:
//         - only two middle nodes selected
//         - we create a parent node
//         - one external incoming edge, one external outgoing edge, one edge between the two selected nodes
//         */
//        let selectedNodeId1: NodeId = TestIds._2
//        let selectedNodeId2: NodeId = TestIds._3
//
//        let nodes: PatchNodes = [
//            subtractNode(id: TestIds._1), // 1
//            addPatchNode(nodeId: selectedNodeId1), // 2
//            addPatchNode(nodeId: selectedNodeId2), // 3
//            subtractNode(id: TestIds._4) // 4
//        ]
//
//        let selectedNodes = IdSet([selectedNodeId1, selectedNodeId2])
//
//        // from substract node 1's output to selected add node 2's input
//        let subtract1ToAdd1 = PortEdge(
//            from: OutputCoordinate(portId: 0, nodeId: TestIds._1),
//            to: InputCoordinate(portId: 0, nodeId: selectedNodeId1))
//
//        // from add node 2's output -> add node 3's input
//        let add1ToAdd2 = PortEdge(
//            from: OutputCoordinate(portId: 0, nodeId: selectedNodeId1),
//            to: InputCoordinate(portId: 0, nodeId: selectedNodeId2))
//
//        // from add node 3's output to substract node 4's input
//        let add2ToSubtract2 = PortEdge(
//            from: OutputCoordinate(portId: 0, nodeId: selectedNodeId2),
//            to: InputCoordinate(portId: 0, nodeId: TestIds._4))
//
//        let edges: Edges = [
//            subtract1ToAdd1,
//            add1ToAdd2,
//            add2ToSubtract2
//        ]
//
//        let selection = GraphUISelectionState(selectedNodes: selectedNodes)
//        let uiState = StitchDocumentViewModel(selection: selection)
//        let graphState = GraphState.getTestState(nodes, edges: edges)
//
//        let project = ProjectState(metadata: ProjectMetadata(name: devDefaultProjectName()),
//                                   graph: graphState,
//                                   graphUI: uiState)
//
//        let result = GroupNodeCreatedEvent()
//            .handle(state: project, environment: mockEnvironment)
//            .state!
//
//        let createdGroupNode = result.graph.groupNodesState.values.first!
//        let createdGroupNodeId = createdGroupNode.groupNodeId
//
//        let createdGroupInputSplitterId = createdGroupNode.inputNodes.first!
//        let createdGroupInputSplitter = result.graph
//            .getPatchNode(id: createdGroupInputSplitterId)!
//
//        let createdGroupOutputSplitterId = createdGroupNode.outputNodes.first!
//        let createdGroupOutputSplitter = result.graph
//            .getPatchNode(id: createdGroupOutputSplitterId)!
//
//        // There should only be two patch nodes in the newly created GroupNode
//        XCTAssert(createdGroupNode.patchNodes.count == 2)
//        XCTAssert(createdGroupNode.layerNodes.count == .zero)
//
//        // There should only be 1 input node and 1 output node
//        XCTAssert(createdGroupNode.inputNodes.count == 1)
//        XCTAssert(createdGroupNode.outputNodes.count == 1)
//
//        let expectedNodes: PatchNodesDict = [
//
//            // The original nodes
//            TestIds._1: subtractNode(id: TestIds._1).schema, // 1
//            selectedNodeId1: addPatchNode(nodeId: selectedNodeId1).schema, // 2
//            selectedNodeId2: addPatchNode(nodeId: selectedNodeId2).schema, // 3
//            TestIds._4: subtractNode(id: TestIds._4).schema, // 4
//
//            // Plus the nodes created by Group Creation
//            createdGroupNode.id: createdGroupNode.schema,
//            createdGroupInputSplitterId: createdGroupInputSplitter.schema,
//            createdGroupOutputSplitterId: createdGroupOutputSplitter.schema
//        ]
//
//        let expectedSelectedNodes = IdSet([createdGroupNodeId.id])
//
//        // Confirm that only the newly created GroupNode is selected
//        XCTAssertEqual(result.graphUI.selection.selectedNodes,
//                       expectedSelectedNodes)
//
//        // Confirm that we have the expected nodes
//        XCTAssertEqual(result.graph.allNodes.toSet,
//                       expectedNodes.toValuesArray.toSet)
//
//        // Confirm that GroupState is updated
//        let expectedGroupNode = GroupNode(
//            id: createdGroupNode.id,
//            position: uiState.center.toCGSize,
//            inputNodes: IdList([createdGroupInputSplitterId]),
//            outputNodes: IdList([createdGroupOutputSplitterId]),
//            patchNodes: selectedNodes,
//            layerNodes: IdSet())
//
//        let expectedGroupState: GroupNodesState = [
//            createdGroupNode.groupNodeId: expectedGroupNode
//        ]
//
//        XCTAssertEqual(expectedGroupState,
//                       result.graph.groupNodesState)
//
//        // Confirm that proper edges were created:
//
//        // edge from parentInput's output to single group child's input
//        let inputToChildEdge = PortEdge(
//            from: OutputCoordinate(portId: 0,
//                                   nodeId: createdGroupInputSplitterId),
//            to: InputCoordinate(portId: 0,
//                                nodeId: selectedNodeId1))
//
//        let childToOutputEdge = PortEdge(
//            from: OutputCoordinate(portId: 0,
//                                   nodeId: selectedNodeId2),
//            to: InputCoordinate(portId: 0,
//                                nodeId: createdGroupOutputSplitterId))
//
//        //                log("inputToChildEdge: \(inputToChildEdge)")
//        //                log("childToOutputEdge: \(childToOutputEdge)")
//        //
//        //                result.graph.edges.forEach {
//        //                    log("result.edges: edge $0: \($0)")
//        //                }
//
//        XCTAssert(result.graph.topologicalData.edges.contains(inputToChildEdge))
//        XCTAssert(result.graph.topologicalData.edges.contains(childToOutputEdge))
//
//        // Confirm that intra-group-edge is still around:
//        XCTAssert(result.graph.topologicalData.edges.contains(add1ToAdd2))
//
//        // Confirm that edges between `subtract node 1 -> add node 1` and `add node 2 -> subtract node 2` are gone
//        XCTAssert(!result.graph.topologicalData.edges.contains(subtract1ToAdd1))
//        XCTAssert(!result.graph.topologicalData.edges.contains(add2ToSubtract2))
//
//        // MARK: PART 2: UNCREATE A GROUP
//
//        /*
//         Confirm that:
//         - group node itself is removed
//         - group input and output splitters are removed
//         - edges from and to group splitters are removed
//         - old edges are added back
//         */
//
//        // Uncreate the group
//        let result2: ProjectState = GroupNodeUncreated(groupId: createdGroupNodeId)
//            .handle(state: result)
//            .state!
//
//        // Group node states should be empty
//        XCTAssert(result2.graph.groupNodesState.isEmpty)
//
//        // The group splitters node should be gone
//        XCTAssert(!result2.graph.patchNodes.keys.contains(createdGroupInputSplitterId))
//        XCTAssert(!result2.graph.patchNodes.keys.contains(createdGroupOutputSplitterId))
//
//        // The group splitter edges should be gone
//        XCTAssert(!result2.graph.topologicalData.edges.contains(inputToChildEdge))
//        XCTAssert(!result2.graph.topologicalData.edges.contains(childToOutputEdge))
//
//        // The old edges should be added back
//        XCTAssert(result2.graph.topologicalData.edges.contains(subtract1ToAdd1))
//        XCTAssert(result2.graph.topologicalData.edges.contains(add2ToSubtract2))
//
//        // Edge between the two add nodes should still around:
//        XCTAssert(result2.graph.topologicalData.edges.contains(add1ToAdd2))
//
//    }
//
//    // Similar test as the above, but making sure we do not modify the wireless nodes
//    func testCreateAndUncreateParentWithExternalEdgesAndWirelessNodes() throws {
//
//        // MARK: PART 1: CREATE A GROUP
//
//        /*
//         Simple case:
//         - only two middle nodes selected
//         - we create a parent node
//         - one external incoming edge, one external outgoing edge, one edge between the two selected nodes
//         */
//        let selectedNodeId1: NodeId = TestIds._2
//        let selectedNodeId2: NodeId = TestIds._3
//
//        let wirelessBroadcasterId = TestIds._5
//        let wirelessReceiverId = TestIds._6
//
//        let nodes: PatchNodes = [
//            subtractNode(id: TestIds._1), // 1
//            addPatchNode(nodeId: selectedNodeId1), // 2
//            addPatchNode(nodeId: selectedNodeId2), // 3
//            subtractNode(id: TestIds._4), // 4
//            wirelessBroadcasterNode(id: wirelessBroadcasterId), // 5
//            wirelessReceiverNode(id: wirelessReceiverId) // 6
//        ]
//
//        // from substract node 1's output to selected add node 2's input
//        let subtract1ToAdd1 = PortEdge(
//            from: OutputCoordinate(portId: 0, nodeId: TestIds._1),
//            to: InputCoordinate(portId: 0, nodeId: selectedNodeId1))
//
//        // from add node 2's output -> add node 3's input
//        let add1ToAdd2 = PortEdge(
//            from: OutputCoordinate(portId: 0, nodeId: selectedNodeId1),
//            to: InputCoordinate(portId: 0, nodeId: selectedNodeId2))
//
//        // from add node 3's output to substract node 4's input
//        let add2ToSubtract2 = PortEdge(
//            from: OutputCoordinate(portId: 0, nodeId: selectedNodeId2),
//            to: InputCoordinate(portId: 0, nodeId: TestIds._4))
//
//        let add1ToBroadcast = PortEdge(
//            from: .init(portId: 0, nodeId: selectedNodeId1),
//            to: .init(portId: 0, nodeId: wirelessBroadcasterId))
//
//        // Initial edges; does not yet include the hidden wireless edge
//        let edges: Edges = [
//            subtract1ToAdd1,
//            add1ToAdd2,
//            add2ToSubtract2,
//            add1ToBroadcast
//        ]
//
//        // We select the two add nodes + the wireless receiver;
//        // the two subtract nodes and wireless broadcaster will stay outside the group
//        let selectedNodes = IdSet([selectedNodeId1, selectedNodeId2, wirelessReceiverId])
//
//        let selection = GraphUISelectionState(selectedNodes: selectedNodes)
//        let uiState = StitchDocumentViewModel(selection: selection)
//        let graphState = GraphState.getTestState(nodes, edges: edges)
//
//        let project = ProjectState(metadata: ProjectMetadata(name: devDefaultProjectName()),
//                                   graph: graphState,
//                                   graphUI: uiState)
//
//        // Assign broadcaster to receiver
//        let result0 = SetBroadcastForWirelessReceiver(broadcasterNodeId: wirelessBroadcasterId,
//                                                      receiverNodeId: wirelessReceiverId)
//            .handle(state: project, environment: mockEnvironment)
//            .state!
//
//        let hiddenWirelessEdge = PortEdge(
//            from: .init(portId: 0, nodeId: wirelessBroadcasterId),
//            to: .init(portId: 0, nodeId: wirelessReceiverId))
//
//        XCTAssert(result0.graph.edges.contains(hiddenWirelessEdge))
//
//        let updatedWirelessReceiverNode = result0.graph.getPatchNode(id: wirelessReceiverId)!
//
//        let result = GroupNodeCreatedEvent()
//            .handle(state: result0, environment: mockEnvironment)
//            .state!
//
//        let createdGroupNode = result.graph.groupNodesState.values.first!
//        let createdGroupNodeId = createdGroupNode.groupNodeId
//
//        let createdGroupInputSplitterId = createdGroupNode.inputNodes.first!
//        let createdGroupInputSplitter = result.graph
//            .getPatchNode(id: createdGroupInputSplitterId)!
//
//        let createdGroupOutputSplitterId = createdGroupNode.outputNodes.first!
//        let createdGroupOutputSplitter = result.graph
//            .getPatchNode(id: createdGroupOutputSplitterId)!
//
//        // The second group output splitter
//        let createdGroupOutputSplitterId2 = createdGroupNode.outputNodes[safe: 1]!
//        let createdGroupOutputSplitter2 = result.graph
//            .getPatchNode(id: createdGroupOutputSplitterId2)!
//
//        // There should be patch nodes in the newly created GroupNode: 2 add nodes and 1 receiver
//        XCTAssertEqual(createdGroupNode.patchNodes.count, 3)
//        XCTAssertEqual(createdGroupNode.layerNodes.count, .zero)
//
//        // There should only be 1 input node;
//        // the wireless receiver's hidden edge should have been ignored
//        XCTAssertEqual(createdGroupNode.inputNodes.count, 1)
//
//        // Two output nodes, one with a (non-hidden) edge going out to a broadcaster's input,
//        // the other with an edge to an outside substract node.
//        XCTAssertEqual(createdGroupNode.outputNodes.count, 2)
//
//        let expectedNodes: PatchNodesDict = [
//
//            // The original nodes
//            TestIds._1: subtractNode(id: TestIds._1).schema, // 1
//            selectedNodeId1: addPatchNode(nodeId: selectedNodeId1).schema, // 2
//            selectedNodeId2: addPatchNode(nodeId: selectedNodeId2).schema, // 3
//            TestIds._4: subtractNode(id: TestIds._4).schema, // 4
//            wirelessBroadcasterId: wirelessBroadcasterNode(id: wirelessBroadcasterId).schema, // 5
//
//            // preferably use the wireless receiver that had received an assignment
//            updatedWirelessReceiverNode.id: updatedWirelessReceiverNode.schema,
//
//            // Plus the nodes created by Group Creation
//            createdGroupNode.id: createdGroupNode.schema,
//            createdGroupInputSplitterId: createdGroupInputSplitter.schema,
//            createdGroupOutputSplitterId: createdGroupOutputSplitter.schema,
//            createdGroupOutputSplitterId2: createdGroupOutputSplitter2.schema
//        ]
//
//        let expectedSelectedNodes = IdSet([createdGroupNodeId.id])
//
//        // Confirm that only the newly created GroupNode is selected
//        XCTAssertEqual(result.graphUI.selection.selectedNodes,
//                       expectedSelectedNodes)
//
//        // Confirm that we have the expected nodes
//        XCTAssertEqual(result.graph.allNodes.toSet,
//                       expectedNodes.toValuesArray.toSet)
//
//        // Confirm that GroupState is updated
//        let expectedGroupNode = GroupNode(
//            id: createdGroupNode.id,
//            position: uiState.center.toCGSize,
//            inputNodes: IdList([createdGroupInputSplitterId]),
//            outputNodes: IdList([createdGroupOutputSplitterId,
//                                 createdGroupOutputSplitterId2]),
//            patchNodes: selectedNodes,
//            layerNodes: IdSet())
//
//        let expectedGroupState: GroupNodesState = [
//            createdGroupNode.groupNodeId: expectedGroupNode
//        ]
//
//        XCTAssertEqual(expectedGroupState,
//                       result.graph.groupNodesState)
//
//        // Confirm that proper edges were created:
//
//        // edge from parentInput's output to single group child's input
//        let inputToChildEdge = PortEdge(
//            from: OutputCoordinate(portId: 0,
//                                   nodeId: createdGroupInputSplitterId),
//            to: InputCoordinate(portId: 0,
//                                nodeId: selectedNodeId1))
//
//        let childToOutputEdge = PortEdge(
//            from: OutputCoordinate(portId: 0,
//                                   nodeId: selectedNodeId2),
//            to: InputCoordinate(portId: 0,
//                                //                                nodeId: createdGroupOutputSplitterId))
//                                nodeId: createdGroupOutputSplitterId2))
//
//        //        log("inputToChildEdge: \(inputToChildEdge)")
//        //        log("childToOutputEdge: \(childToOutputEdge)")
//        //
//        //        result.graph.edges.forEach {
//        //            log("result.edges: edge $0: \($0)")
//        //        }
//
//        XCTAssert(result.graph.topologicalData.edges.contains(inputToChildEdge))
//
//        // TODO: actual app seems okay and rest of test passes; look into why this edge isn't found
//        //        XCTAssert(result.graph.topologicalData.edges.contains(childToOutputEdge))
//
//        // Confirm that intra-group-edge is still around:
//        XCTAssert(result.graph.topologicalData.edges.contains(add1ToAdd2))
//
//        // Confirm that hidden wireless edge is still around:
//        XCTAssert(result.graph.topologicalData.edges.contains(hiddenWirelessEdge))
//
//        // Confirm that edges between `subtract node 1 -> add node 1` and `add node 2 -> subtract node 2` are gone
//        XCTAssert(!result.graph.topologicalData.edges.contains(subtract1ToAdd1))
//        XCTAssert(!result.graph.topologicalData.edges.contains(add2ToSubtract2))
//
//        // MARK: PART 2: UNCREATE A GROUP
//
//        /*
//         Confirm that:
//         - group node itself is removed
//         - group input and output splitters are removed
//         - edges from and to group splitters are removed
//         - old edges are added back
//         */
//
//        // Uncreate the group
//        let result2: ProjectState = GroupNodeUncreated(groupId: createdGroupNodeId)
//            .handle(state: result)
//            .state!
//
//        // Group node states should be empty
//        XCTAssert(result2.graph.groupNodesState.isEmpty)
//
//        // The group splitters node should be gone
//        XCTAssert(!result2.graph.patchNodes.keys.contains(createdGroupInputSplitterId))
//        XCTAssert(!result2.graph.patchNodes.keys.contains(createdGroupOutputSplitterId))
//        XCTAssert(!result2.graph.patchNodes.keys.contains(createdGroupOutputSplitterId2))
//
//        // The group splitter edges should be gone
//        XCTAssert(!result2.graph.topologicalData.edges.contains(inputToChildEdge))
//        XCTAssert(!result2.graph.topologicalData.edges.contains(childToOutputEdge))
//
//        // The old edges should be added back
//        XCTAssert(result2.graph.topologicalData.edges.contains(subtract1ToAdd1))
//        XCTAssert(result2.graph.topologicalData.edges.contains(add2ToSubtract2))
//
//        // Edge between the two add nodes should still around:
//        XCTAssert(result2.graph.topologicalData.edges.contains(add1ToAdd2))
//        XCTAssert(result2.graph.topologicalData.edges.contains(hiddenWirelessEdge))
//
//    }
//
//    /// The following tests:
//    /// 1. Multiple edges into a group's input
//    /// 2. Inclusion of layer node in group
//    /// 3. Group in group
//    func testGroupNodeMultipleInputsAndGroupception() throws {
//        let patchNodes: PatchNodesDict = [
//            TestIds._0: splitterPatchNode(nodeId: TestIds._0).schema,
//            TestIds._1: splitterPatchNode(nodeId: TestIds._1).schema,
//            TestIds._2: addPatchNode(nodeId: TestIds._2).schema
//        ]
//
//        let layerNodes: LayerNodesDict = [
//            TestIds._3: textLayerNode(id: TestIds._3).schema
//        ]
//
//        let edges: Edges = [
//            PortEdge(from: OutputCoordinate(portId: 1, nodeId: TestIds._0),
//                     to: InputCoordinate(portId: 0, nodeId: TestIds._2)),
//            PortEdge(from: OutputCoordinate(portId: 1, nodeId: TestIds._1),
//                     to: InputCoordinate(portId: 0, nodeId: TestIds._2))
//        ]
//        let connections = getConnections(from: edges)
//
//        let graph = GraphState(patchNodes: patchNodes,
//                               layerNodes: layerNodes,
//                               connections: connections)
//
//        let uiState = StitchDocumentViewModel()
//
//        var state = createTestGroupNode(
//            graph: graph,
//            selectedNodes: IdSet([TestIds._2, TestIds._3]),
//            environment: mockEnvironment)
//
//        let expectedGroupNode = GroupNode(
//            id: TestIds._6,
//            position: uiState.center.toCGSize,
//            inputNodes: IdList([TestIds._4, TestIds._5]),
//            patchNodes: IdSet([TestIds._2]),
//            layerNodes: IdSet([TestIds._3])
//        )
//
//        let actualGroupNode = state.graph.groupNodesState.values.first!
//
//        XCTAssertEqual(actualGroupNode.patchNodes, expectedGroupNode.patchNodes)
//        XCTAssertEqual(actualGroupNode.layerNodes, expectedGroupNode.layerNodes)
//
//        // How to compare the actual edges themselves?
//        //        XCTAssertEqual(actualGroupNode.inputNodes, expectedGroupNode.inputNodes)
//        XCTAssertEqual(actualGroupNode.inputNodes.count, expectedGroupNode.inputNodes.count)
//
//        //        XCTAssertEqual(expectedGroupNode, actualGroupNode)
//
//        /// **
//        /// Next test takes this group, adds a new Splitter node, and creates a GroupNode from
//        /// the first GroupNode and the new Splitter node.
//        /// **
//        state = NodeCreatedAction(choice: .patch(.splitter))
//            .handle(state: state,
//                    environment: mockEnvironment)
//            .state!
//
//        let splitterId: NodeId = state.graph.patchNodesAsList.nodes(for: .splitter).first!.id
//
//        // Select the group node and the new splitter node
//        let selectedNodes = IdList([actualGroupNode.id,
//                                    splitterId])
//
//        state = createTestGroupNode(graph: state.graph,
//                                    selectedNodes: IdSet(selectedNodes),
//                                    environment: mockEnvironment)
//
//        let secondGroupNode: GroupNode = state.graph.groupNodesState.values.first {
//            $0.id != actualGroupNode.id
//        }!
//
//        let expectedGroupInGroupNode = GroupNode(
//            id: secondGroupNode.id,
//            position: uiState.center.toCGSize,
//            patchNodes: IdSet([splitterId]),
//            layerNodes: IdSet([]),
//            groupNodes: GroupIdSet([actualGroupNode.groupNodeId]))
//
//        //        let actualGroupInGroupNode = state.graph.groupNodesState[TestIds._8.asGroupNodeId]!
//        //        let actualGroupInGroupNode = secondGroupNode
//        //        XCTAssertEqual(expectedGroupInGroupNode, actualGroupInGroupNode)
//
//        XCTAssertEqual(secondGroupNode.patchNodes, expectedGroupInGroupNode.patchNodes)
//        XCTAssertEqual(secondGroupNode.layerNodes, expectedGroupInGroupNode.layerNodes)
//        XCTAssertEqual(secondGroupNode.groupNodes, expectedGroupInGroupNode.groupNodes)
//
//        // How to compare the actual edges themselves?
//        //        XCTAssertEqual(secondGroupNode.inputNodes, expectedGroupInGroupNode.inputNodes)
//
//        // Shouldn't this be correct? Why is this failing?
//        //        XCTAssertEqual(secondGroupNode.inputNodes.count, expectedGroupInGroupNode.inputNodes.count)
//    }
//
//    // Tests input addition and removal from group node
//    func testGroupNodeInputsChanged() throws {
//
//        let splitterNodeId: NodeId = TestIds._0
//        let groupNodeId: GroupNodeId = TestIds._1.asGroupNodeId
//
//        let splitterNode = splitterPatchNode(nodeId: splitterNodeId)
//
//        let groupNodes: GroupNodesDict = [groupNodeId: GroupNode(id: groupNodeId.id,
//                                                                 patchNodes: IdSet([splitterNodeId]),
//                                                                 layerNodes: IdSet())]
//        let groupNodesState: GroupNodesState = groupNodes
//        var state = GraphState(groupNodesState: groupNodesState)
//        state.updatePatchNode(splitterNode)
//
//        // TODO: update this test to look at connections as well;
//        // need to e.g. create a proper GroupNodesState via GroupNodeCreated action,
//        // so that we will have expected edges etc.
//
//        // Add the input
//        state = setSplitterType(
//            group: state.groupNodesState[groupNodeId]!,
//            splitterNodeId: splitterNode.id,
//            newType: .input,
//            currentType: .inline,
//            activeGroupId: groupNodeId,
//            state: state)
//
//        // Test for new output node in group node state
//        let expectedInputNodes = IdList([splitterNodeId])
//        let actualInputNodes = state.groupNodesState[groupNodeId]!.inputNodes
//        XCTAssertEqual(expectedInputNodes, actualInputNodes)
//
//        // Next test removes Input
//        var projectState = devDefaultProject()
//        projectState.graph = state
//
//        // remove input
//        projectState.graph = setSplitterType(
//            group: projectState.graph.groupNodesState[groupNodeId]!,
//            splitterNodeId: splitterNode.id,
//            newType: .inline,
//            currentType: .input,
//            activeGroupId: groupNodeId,
//            state: projectState.graph)
//
//        let expectedEmptyInputNodes = IdList()
//        let actualEmptyInputNodes = projectState.graph.groupNodesState[groupNodeId]!.inputNodes
//
//        let splitter = projectState.graph.getPatchNode(id: splitterNodeId)!
//        XCTAssertEqual(.inline,
//                       projectState.graph.groupNodesState.splitterType(splitter.id))
//
//        // this test should pass...
//        XCTAssertEqual(expectedEmptyInputNodes, actualEmptyInputNodes)
//    }
//
//    func testGroupNodeInputDuplicated() throws {
//
//        let splitterNodeId: NodeId = TestIds._0
//        let groupNodeId: GroupNodeId = TestIds._1.asGroupNodeId
//
//        let splitterNode = splitterPatchNode(nodeId: splitterNodeId)
//
//        let groupNodes: GroupNodesDict = [groupNodeId: GroupNode(id: groupNodeId.id,
//                                                                 patchNodes: IdSet([splitterNodeId]),
//                                                                 layerNodes: IdSet())]
//        let groupNodesState: GroupNodesState = groupNodes
//        var state = GraphState(groupNodesState: groupNodesState)
//        state.updatePatchNode(splitterNode)
//
//        // TODO: update this test to look at connections as well;
//        // need to e.g. create a proper GroupNodesState via GroupNodeCreated action,
//        // so that we will have expected edges etc.
//
//        // Add the input
//        state = setSplitterType(
//            group: state.groupNodesState[groupNodeId]!,
//            splitterNodeId: splitterNode.id,
//            newType: .input,
//            currentType: .inline,
//            activeGroupId: groupNodeId,
//            state: state)
//
//        // Test for new output node in group node state
//        let expectedInputNodes = IdList([splitterNodeId])
//        let actualInputNodes = state.groupNodesState[groupNodeId]!.inputNodes
//        XCTAssertEqual(expectedInputNodes, actualInputNodes)
//
//        state.connections = state.connections.addEdge(.init(from: .fakeOutputCoordinate,
//                                                            to: .init(portId: 0, nodeId: splitterNode.id)))
//        let graphUI = StitchDocumentViewModel(selection: .init(selectedNodes: ([splitterNode.id]),
//                                                    lastSelectedNode: splitterNode.id))
//        let projectState = ProjectState(metadata: .fakeProjectMetadata,
//                                        graph: state,
//                                        computedGraph: .init(graphUI: graphUI))
//
//        // Then duplicate the node
//        let updatedState = SelectedGraphNodesDuplicated()
//            .handle(state: AppState().fromProject(projectState),
//                    environment: .init())
//            .state!
//
//        // Expected:
//        // -- graph state has two input splitter nodes (the original and the copy)
//        // -- both input splitter nodes belong to same group
//        // -- the duplicated input splitter node does NOT have an incoming edge
//
//        let splitterNodes = updatedState.currentProject!.graph.fullPatchNodesAsList.filter {
//            $0.patchName! == .splitter
//        }
//
//        XCTAssertEqual(splitterNodes.count, 2)
//
//        let copiedInputSplitter = splitterNodes.first {
//            $0.patchName! == .splitter && $0.id != splitterNode.id
//        }
//
//        XCTAssert(copiedInputSplitter.isDefined)
//
//        let copiedInputHasIncomingEdge = updatedState.currentProject!.graph.connections.contains(where: { (_: OutputCoordinate, value: Set<InputCoordinate>) in
//            value.contains(copiedInputSplitter!.inputsWithCoordinates.first!.id)
//        })
//
//        XCTAssertFalse(copiedInputHasIncomingEdge)
//
//        let expectedInputNodes2 = Set(splitterNodes.map { $0.id })
//        let actualInputNodes2 = Set(state.groupNodesState[groupNodeId]!.inputNodes)
//
//        XCTAssertEqual(expectedInputNodes2, actualInputNodes2)
//    }
//
//    // Tests output addition and removal from group node (same as above test)
//    func testGroupNodeOutputsChanged() throws {
//
//        let splitterNodeId: NodeId = TestIds._0
//        let groupNodeId: GroupNodeId = TestIds._1.asGroupNodeId
//
//        let splitterNode = splitterPatchNode(nodeId: splitterNodeId)
//
//        let groupNodes: GroupNodesDict = [groupNodeId: GroupNode(id: groupNodeId.id,
//                                                                 patchNodes: IdSet([splitterNodeId]),
//                                                                 layerNodes: IdSet())]
//        let groupNodesState: GroupNodesState = groupNodes
//        var state = GraphState(groupNodesState: groupNodesState)
//        state.updatePatchNode(splitterNode)
//
//        // add output
//        state = setSplitterType(
//            group: state.groupNodesState[groupNodeId]!,
//            splitterNodeId: splitterNode.id,
//            newType: .output,
//            currentType: .inline,
//            activeGroupId: groupNodeId,
//            state: state)
//
//        let expectedOutputNodes = IdList([splitterNodeId])
//        let actualOutputNodes = state.groupNodesState[groupNodeId]!.outputNodes
//        XCTAssertEqual(expectedOutputNodes, actualOutputNodes)
//
//        // Next test removes output
//        var projectState = devDefaultProject()
//        projectState.graph = state
//
//        // remove output
//        projectState.graph = setSplitterType(
//            group: state.groupNodesState[groupNodeId]!,
//            splitterNodeId: splitterNode.id,
//            newType: .inline,
//            currentType: .output,
//            activeGroupId: groupNodeId,
//            state: projectState.graph)
//
//        let splitter = projectState.graph.getPatchNode(id: splitterNodeId)!
//        XCTAssertEqual(.inline,
//                       projectState.graph.groupNodesState.splitterType(splitter.id))
//
//        let expectedEmptyOutputNodes = IdList()
//        let actualEmptyOutputNodes = projectState.graph
//            .groupNodesState[groupNodeId]!.outputNodes
//
//        XCTAssertEqual(expectedEmptyOutputNodes, actualEmptyOutputNodes)
//
//        // Assert each GroupOutput id is unique:
//        XCTAssertEqual(actualEmptyOutputNodes.count,
//                       IdSet(actualEmptyOutputNodes).count)
//    }
//
//    // Tests creating a group node inside another group node, and editing group names
//    func testGroupInGroup() throws {
//        let patchNodes: PatchNodesDict = [
//            TestIds._0: splitterPatchNode(nodeId: TestIds._0).schema
//        ]
//
//        let graphState = GraphState(patchNodes: patchNodes)
//        var state = ProjectState(metadata: ProjectMetadata(name: devDefaultProjectName()),
//                                 graph: graphState)
//
//        // Create the first group
//        state = NodeTappedAction(id: TestIds._0).handle(state: state).state!
//        state = GroupNodeCreatedEvent().handle(state: state,
//                                               environment: mockEnvironment).state!
//        let createdGroupNodeId = state.graph.groupNodesState.first!.key
//
//        XCTAssertEqual(Array(state.graph.groupNodesState.keys), [createdGroupNodeId])
//
//        // Go into the first group
//        state = SetActiveGroupEvent(id: createdGroupNodeId).handle(state: state).state!.graphUI
//
//        // Create a second group inside the first group
//        state = NodeTappedAction(id: TestIds._0).handle(state: state).state!
//        state = GroupNodeCreatedEvent().handle(state: state,
//                                               environment: mockEnvironment).state!
//
//        let secondCreatedGroupNodeId = state.graph.groupNodesState.first { $0.key != createdGroupNodeId }!.key
//        XCTAssertEqual(GroupIdSet(Array(state.graph.groupNodesState.keys)),
//                       GroupIdSet([createdGroupNodeId,
//                                   secondCreatedGroupNodeId]))
//
//        XCTAssertEqual(state.graph.groupNodesState[createdGroupNodeId]!.groupNodes,
//                       GroupIdSet([secondCreatedGroupNodeId]))
//
//        XCTAssertEqual(state.graph.groupNodesState[secondCreatedGroupNodeId]!.groupNodes,
//                       GroupIdSet())
//
//        // Select the second group and put it into a new, third group
//        // NOTE: technically must always select more than one node to create a group...
//        state = NodeTappedAction(id: secondCreatedGroupNodeId.id).handle(state: state).state!
//
//        state = GroupNodeCreatedEvent().handle(state: state,
//                                               environment: mockEnvironment).state!
//
//        let thirdCreatedGroupNodeId = state.graph.groupNodesState.first { $0.key != createdGroupNodeId && $0.key != secondCreatedGroupNodeId}!.key
//
//        XCTAssertEqual(GroupIdSet(Array(state.graph.groupNodesState.keys)),
//                       GroupIdSet([createdGroupNodeId,
//                                   secondCreatedGroupNodeId,
//                                   thirdCreatedGroupNodeId]))
//
//        XCTAssertEqual(GroupIdSet(Array(state.graph.groupNodesState[secondCreatedGroupNodeId]!.groupNodes)),
//                       GroupIdSet())
//
//        XCTAssertEqual(GroupIdSet(Array(state.graph
//                                            .groupNodesState[thirdCreatedGroupNodeId]!.groupNodes)),
//                       GroupIdSet([secondCreatedGroupNodeId]))
//
//        // Group node id 1 used to contain group node 2, but it's now 3
//        XCTAssertEqual(GroupIdSet(Array(state.graph.groupNodesState[createdGroupNodeId]!.groupNodes)),
//                       GroupIdSet([thirdCreatedGroupNodeId]))
//
//        // The patch node is now in group 2
//        XCTAssertEqual(IdSet(Array(state.graph.groupNodesState[secondCreatedGroupNodeId]!.patchNodes)),
//                       IdSet([TestIds._0]))
//        XCTAssertEqual(IdSet(Array(state.graph.groupNodesState[thirdCreatedGroupNodeId]!.patchNodes)),
//                       IdSet())
//        XCTAssertEqual(IdSet(Array(state.graph.groupNodesState[createdGroupNodeId]!.patchNodes)),
//                       IdSet())
//
//        // TEST: editing project name from within graph-view/top-bar
//
//        let projectNameEdit = "Edited Project Name"
//        let projectsDict: ProjectsDict = [state.metadata.projectId: .loaded(ProjectSchema(metadata: state.metadata))]
//        let appState = AppState(stitchProjectsState: StitchProjects(projectsDict: projectsDict),
//                                currentProject: state)
//
//        state = ProjectNameEdited(newName: projectNameEdit,
//                                  id: state.metadata.projectId)
//            .handle(state: appState)
//            .state!.currentProject!
//
//        XCTAssertEqual(state.metadata.name, projectNameEdit)
//
//        // TEST: editing project name from within graph-view/top-bar
//
//        let groupNodeNameEdit = "Edited Group Name"
//        let groupNodeId: GroupNodeId = secondCreatedGroupNodeId
//        state = GroupNodeNameEdited(id: groupNodeId,
//                                    edit: groupNodeNameEdit)
//            .handle(state: state)
//            .state!
//
//        XCTAssertEqual(
//            state.graph.getGroupNode(id: groupNodeId)!.schema.customName,
//            groupNodeNameEdit)
//
//    }
//
//    func testGroupNodeUngrouped() {
//
//        // Initial nodes; using different kinds just for clarity;
//        // not specific to add vs subtract etc.
//        let nodes: PatchNodesDict = [
//            TestIds._1: addPatchNode(nodeId: TestIds._1).schema,
//            TestIds._2: subtractNode(id: TestIds._2).schema
//        ]
//
//        // Put all the nodes in group
//        let graph = GraphState(patchNodes: nodes)
//        var state: ProjectState = createTestGroupNode(
//            graph: graph,
//            selectedNodes: nodes.keys.toSet,
//            environment: .init())
//
//        // Confirm we have expected nodes in group
//        let firstGroupNodeId = state.graph.groupNodesState.first!.key
//        let firstGroup: GroupNode = state.graph.groupNodesState.get(firstGroupNodeId)!
//
//        //        let ids = IdSet([TestIds._1, TestIds._2])
//
//        XCTAssertEqual(firstGroup.patchNodes, IdSet([TestIds._1, TestIds._2]))
//
//        // Uncreate the group
//        state = GroupNodeUncreated(groupId: firstGroupNodeId).handle(state: state).state!
//
//        // We should have no more group nodes
//        XCTAssertEqual(state.graph.groupNodesState,
//                       GroupNodesState())
//
//        // But should still have the original nodes
//        XCTAssertEqual(state.graph.patchNodes.keys.toSet,
//                       IdSet([TestIds._1, TestIds._2]))
//    }
//
//    // We have a nested group structure like: top level -> G1 -> G2,
//    // and when we ungroup G2, we expect G2's nodes to be in G1 and not top level.
//    func testGroupNodeUngroupedToplevel() {
//
//        // Initial nodes; using different kinds just for clarity;
//        // not specific to add vs subtract etc.
//        let nodes: PatchNodesDict = [
//            TestIds._1: addPatchNode(nodeId: TestIds._1).schema,
//            TestIds._2: subtractNode(id: TestIds._2).schema,
//            TestIds._3: multiplyPatchNode(id: TestIds._3).schema,
//            TestIds._4: dividePatchNode(id: TestIds._4).schema,
//            TestIds._5: minNode(id: TestIds._5).schema,
//            TestIds._6: maxNode(id: TestIds._6).schema
//        ]
//
//        // Put all nodes in the first group G1
//        let graph = GraphState(patchNodes: nodes)
//        var state: ProjectState = createTestGroupNode(
//            graph: graph,
//            selectedNodes: nodes.keys.toSet,
//            environment: .init())
//
//        // Go inside first group G1 ...
//        let firstGroupNodeId = state.graph.groupNodesState.first!.key
//        state = SetActiveGroupEvent(id: firstGroupNodeId)
//            .handle(state: state).state!.graphUI
//
//        // ... and create a second group G2 from e.g. the multiply and divide nodes
//        state.selection.selectedNodes = .init(arrayLiteral: TestIds._3, TestIds._4)
//        state = GroupNodeCreatedEvent().handle(
//            state: state,
//            environment: mockEnvironment).state!
//
//        // then we uncreate G2; G2's nodes (multiply, divide) should now be in G1, and not at top level.
//        let secondGroupNodeId: GroupNodeId = state.graph.groupNodesState.first { $0.key != firstGroupNodeId }!.key
//
//        state = GroupNodeUncreated(groupId: secondGroupNodeId).handle(state: state).state!
//
//        let firstGroup: GroupNode = state.graph.groupNodesState.get(firstGroupNodeId)!
//        log("testGroupNodeUngroupedNested: firstGroup: \(firstGroup)")
//        let expectedGroup1Nodes: IdSet = .init(nodes.keys.toSet)
//
//        // There should only be one group
//        XCTAssertEqual(state.graph.groupNodesState.keys.count, 1)
//
//        // We should still have all the nodes in GraphState
//        XCTAssertEqual(state.graph.patchNodes.keys.toSet, expectedGroup1Nodes)
//
//        // G1 should contain all nodes now
//        XCTAssertEqual(firstGroup.patchNodes, expectedGroup1Nodes)
//    }
//
// }
//
//// func createTestGroupNode(graph: GraphState,
////                         selectedNodes: IdSet,
////                         environment: StitchEnvironment) -> ProjectState {
////    let selection = GraphUISelectionState(selectedNodes: selectedNodes)
////    let graphUI = StitchDocumentViewModel(selection: selection)
////    let project = ProjectState(metadata: ProjectMetadata(name: devDefaultProjectName()),
////                               graph: graph,
////                               graphUI: graphUI)
////
////    return GroupNodeCreatedEvent()
////        .handle(state: project, environment: environment)
////        .state!
//// }

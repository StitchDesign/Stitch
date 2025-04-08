//
//  TestStateUtils.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 4/10/23.
//

import Foundation
import XCTest
@testable import Stitch

// func loadSchemaAndCalculateGraph(from schema: ProjectSchema) {
//    let state = AppState()
//    // Process effect to build project
//    let result = setCurrentProjectResult(from: schema,
//                                         state: state)
//
//    guard let projectState = result.state.currentProject else {
//        XCTFail("loadSchemaAndCalculateGraph: no project state found")
//        return
//    }
//
//    // Just checks that no crashes happen on calculation
//    let _ = recalculateGraphFromState(graphState: projectState.graph,
//                                      computedGraphState: projectState.computedGraph,
//                                      environment: StitchEnvironment())
// }

// func getAppStateWithProject(_ name: String = STITCH_PROJECT_DEFAULT_NAME) -> SetCurrentProjectResult {
//    getAppStateWithProject(devDefaultProjectSchema(name))
// }
//
// func getAppStateWithProject(_ name: String,
//                            _ projectState: ProjectSchema) -> SetCurrentProjectResult {
//    var projectState = projectState
//    projectState.metadata.name = name
//    return getAppStateWithProject(projectState)
// }
//
// func getAppStateWithProject(_ projectState: ProjectSchema) -> SetCurrentProjectResult {
//    let appState = AppState()
//    return setCurrentProjectResult(from: projectState,
//                                   state: appState)
// }

// let MOCK_APP_STATE_PROJECT_SELECTED = AppState(currentGraphId: devDefaultProject().id)

// extension GraphState {
//    static func getTestState(_ nodes: [any Node],
//                             existingState: GraphState? = nil,
//                             edges: Edges = [],
//                             projectURL: ProjectURL? = nil) -> GraphState {
//        let state = existingState ?? GraphState()
//        state.connections = getConnections(from: edges)
//
//        nodes.forEach { node in
//            if let patchNode = node as? PatchNode {
//                state.updatePatchNode(patchNode)
//            } else if let layerNode = node as? LayerNode {
//                state.updateLayerNode(layerNode)
//            } else {
//                fatalError("GraphState.getTestState: expected patch or layer but got something else")
//            }
//        }
//
//        state.topologicalData = .init(state: state)
//
//        return state
//    }
// }

// extension ProjectState {
//    static func getProjectTestState(_ nodes: [any Node],
//                                    edges: Edges = [],
//                                    projectURL: ProjectURL? = nil) -> Self {
//
//        ProjectState(metadata: ProjectMetadata(name: "Project Test State"),
//                     graph: .getTestState(nodes,
//                                          edges: edges,
//                                          projectURL: projectURL))
//    }
// }

// func getCycleTestState() -> GraphState {
//
//    let node1 = addPatchNode(nodeId: TestIds._1, n2: 10)
//    let node2 = addPatchNode(nodeId: TestIds._2, n2: 20)
//
//    let edges = [
//        PortEdge(from: .init(portId: 0, nodeId: TestIds._1), to: .init(portId: 0, nodeId: TestIds._2)),
//        PortEdge(from: .init(portId: 0, nodeId: TestIds._2), to: .init(portId: 0, nodeId: TestIds._1))
//    ]
//
//    return GraphState.getTestState([node1, node2], edges: edges)
// }

// func getLongerCycleTestState() -> GraphState {
//
//    let node1 = addPatchNode(nodeId: TestIds._1, n2: 10)
//    let node2 = addPatchNode(nodeId: TestIds._2, n2: 20)
//    let node3 = addPatchNode(nodeId: TestIds._3, n2: 30)
//
//    // 1 -> 2
//    // 2 -> 3
//    // 3 -> 1
//    let edges = [
//        PortEdge(from: .init(portId: 0, nodeId: TestIds._1), to: .init(portId: 0, nodeId: TestIds._2)),
//        PortEdge(from: .init(portId: 0, nodeId: TestIds._2), to: .init(portId: 0, nodeId: TestIds._3)),
//        PortEdge(from: .init(portId: 0, nodeId: TestIds._3), to: .init(portId: 0, nodeId: TestIds._1))
//    ]
//
//    return GraphState.getTestState([node1, node2, node3], edges: edges)
// }

// func getNonCycleTestState() -> GraphState {
//
//    let node1 = addPatchNode(nodeId: TestIds._1, n2: 10)
//    let node2 = addPatchNode(nodeId: TestIds._2, n2: 20)
//
//    // 1 -> 2
//    let edges = [
//        PortEdge(from: .init(portId: 0, nodeId: TestIds._1), to: .init(portId: 0, nodeId: TestIds._2))
//    ]
//
//    return GraphState.getTestState([node1, node2], edges: edges)
// }

// PULSE

// func pulseTestState() -> (GraphState, GraphStepState) {
//
//    let repeatingPulseId: NodeId = TestIds._1
//
//    let pulseTestNodes: [any Node] = [
//        repeatingPulseNode(id: repeatingPulseId,
//                           time: 1), // ie should pulse after 1 second
//        counterPatchNode(id: TestIds._2),
//        // skip node 3
//        splitterPatchNode(nodeId: TestIds._4),
//        textLayerNode(id: TestIds._5)
//    ]
//
//    let pulseTestEdges: Edges = [
//        // edge from rp to counter
//        PortEdge(from: OutputCoordinate(portId: 1, nodeId: TestIds._1),
//                 to: InputCoordinate(portId: 0, nodeId: TestIds._2)),
//
//        // edge from second splitter to text
//        PortEdge(from: OutputCoordinate(portId: 1, nodeId: TestIds._4),
//                 to: InputCoordinate(portId: 0, nodeId: TestIds._5))
//    ]
//
//    let graphState = GraphState.getTestState(pulseTestNodes,
//                                             edges: pulseTestEdges)
//
//    let graphStepState = GraphStepState.setGraphInPast()
//    return (graphState, graphStepState)
// }

func getConnections(from edges: Edges) -> Connections {
    edges.reduce(into: [:]) { partialResult, edge in
        if partialResult.keys.contains(edge.from) {
            partialResult[edge.from]!.insert(edge.to)
        } else {
            partialResult.updateValue(Set([edge.to]), forKey: edge.from)
        }
    }
}

//
//  NodeTypeChangedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/8/21.
//

import Foundation
import StitchSchemaKit

// Easier to find than `nodeTypeChanged` which shares same name as several protocol methods.
// Also separates view model update logic from disk-reading/writing side-effects.
struct NodeTypeChangedFromCanvasItemMenu: StitchDocumentEvent {
    let newNodeType: NodeType
    
    @MainActor
    func handle(state: StitchDocumentViewModel) {
        
        let graph = state.visibleGraph
        
        graph.selectedCanvasItems.forEach {
            if let patchNode: PatchNodeViewModel = graph.getPatchNode(id: $0.nodeId),
               patchNode.patch.availableNodeTypes.contains(newNodeType) {
                
                let _ = graph.nodeTypeChanged(nodeId: patchNode.id,
                                              newNodeType: newNodeType,
                                              activeIndex: state.activeIndex,
                                              graphTime: state.graphStepState.graphTime)
                
            }
               
        }
        
        state.encodeProjectInBackground()
    }
}

extension GraphState {
    
    /// Helper used by NodeTypeChanged and GroupNodeCreated (coercing type of group splitters)
    @MainActor
    func nodeTypeChanged(nodeId: NodeId,
                         newNodeType: UserVisibleType,
                         activeIndex: ActiveIndex,
                         graphTime: TimeInterval) -> NodeIdSet? {

        guard let node = self.getNode(nodeId) else {
            log("NodeTypeChangedAction: no change...")
            return nil
        }

        guard let oldType = node.userVisibleType else {
            log("NodeTypeChangedAction: node has no node type, so cannot change")
            return nil
        }

        // Change view model
        let changedNodeIds = self.changeType(
            for: node,
            oldType: oldType,
            newType: newNodeType,
            activeIndex: activeIndex,
            graphTime: graphTime)

        // Recalculate the graph from each of the changed nodes' incoming edges
        let ids = changedNodeIds
            .flatMap { self.immediatelyUpstreamNodes(for: $0) }
            .toSet
            // Always add the node itself, in case node has no incoming edges
            .pureInsert(nodeId)

        self.scheduleForNextGraphStep(ids)
        return ids
    }
    
    @MainActor
    func changeType(for node: NodeViewModel,
                    oldType: UserVisibleType,
                    newType: UserVisibleType,
                    activeIndex: ActiveIndex,
                    graphTime: TimeInterval) -> NodeIdSet {

        guard let patchNode = node.patchNode else {
            fatalErrorIfDebug()
            return .init()
        }

        // Do nothing if node doesn't support type changes
        guard !patchNode.userTypeChoices.isEmpty else {
            log("GraphState.changeType: type change not supported")
            return Set([node.id])
        }
        
        // TODO: no longer relevant now that classic animation node eval op can create a default animation state when necessary? ... But this may also fix an issue with Spring node?
        node.ephemeralObservers?.forEach {
            $0.nodeTypeChanged(
                oldType: oldType,
                newType: newType,
                kind: node.kind)
        }

        // Convert all values which support type changing;
        // Only network node doesn't change inputs.
        if patchNode.patch == .networkRequest {
            // For network request node, we just change the user-visible-type manually.
            patchNode.userVisibleType = newType
        } else {
            node.updateNodeTypeAndInputs(
                newType: newType,
                currentGraphTime: graphTime,
                activeIndex: activeIndex,
                graph: self)
        }

        switch patchNode.patch {
            
        case .networkRequest:
            // TODO: are you properly coercing media etc. ?
            var nodesDownstreamFromSecondOutput = NodeIdSet()
            node.getAllOutputsObservers().enumerated().forEach { index, outputObserver in
                // ONLY the second output of the NetworkRequest changes type
                if index == 1 {
                    let existingValues = outputObserver.allLoopedValues
                    outputObserver.updateOutputValues(existingValues.coerce(to: newType.defaultPortValue,
                                                                            currentGraphTime: graphTime))
                    nodesDownstreamFromSecondOutput = outputObserver.getDownstreamInputsObservers().map(\.id.nodeId).toSet
                }
            }
            return Set([node.id]).union(nodesDownstreamFromSecondOutput)
            
        case .wirelessBroadcaster:
            let updatedReceivers = self.broadcastNodeTypeChange(
                broadcastNodeId: patchNode.id,
                patchNodes: patchNodes,
                connections: self.connections,
                newNodeType: newType,
                graphTime: graphTime,
                activeIndex: activeIndex)
            return Set([node.id]).union(updatedReceivers)
        default:
            return Set([node.id])
        }
    }
}

extension Patch {
    /// Refers to input ports whose types change given a conditional node value type. Returns nil if the node doesn't support type changing.
    @MainActor
    var nonStaticTypedInputPorts: Set<Int>? {
        guard let patchNodeDefinition = self.graphNode,
              let defaultType = patchNodeDefinition.defaultUserVisibleType else {
            // No type changing support
            return nil
        }
        
        let valueDynamicRows = patchNodeDefinition.rowDefinitions(for: defaultType).inputs
            .map { $0.isTypeStatic }
            .enumerated()
            .compactMap { index, isTypeStatic in
                isTypeStatic ? nil : index
            }
        
        return Set(valueDynamicRows)
    }
}

extension SwiftParserPatchData {
    @MainActor
    static func processIncomingConnectionData(upstreamCoordinate: AIGraphData_V0.NodeIndexedCoordinate,
                                              downstreamCoordinate: AIGraphData_V0.NodeIndexedCoordinate,
                                              nativePatchNodes: [String: CurrentAIGraphData.PatchNode],
                                              nativePatchValueTypeSettings: inout [String: CurrentAIGraphData.NativePatchNodeValueTypeSetting],
                                              patchConnections: inout [CurrentAIGraphData.PatchConnection]) {
        guard let patch = nativePatchNodes.get(downstreamCoordinate.node_id)?.node_name.value.patch else {
            fatalErrorIfDebug()
            return
        }
        
        let nodeValueTypeDynamicPortIndices = patch.nonStaticTypedInputPorts ?? .init()
        
        // Determine a custom node value type if this node supports value types and no value has yet been set here
        let checkForValueTypeHere = nodeValueTypeDynamicPortIndices.contains(downstreamCoordinate.port_index) && !nativePatchValueTypeSettings.keys.contains(downstreamCoordinate.node_id)
        
        // Determine node type by examining upstream node
        if checkForValueTypeHere {
            fatalError("deleting this fn")
            
//           if let upstreamValueType = upstreamCoordinate
//            .determineOutputNodeValueType(nativePatchNodes: nativePatchNodes,
//                                          nativePatchValueTypeSettings: nativePatchValueTypeSettings) {
//               nativePatchValueTypeSettings.updateValue(.init(node_id: upstreamCoordinate.node_id,
//                                                              value_type: .init(value: upstreamValueType)) ,
//                                                        forKey: upstreamCoordinate.node_id)
//           }
        }
        
        // Create connection data
        patchConnections.append(
            .init(src_port: upstreamCoordinate,
                  dest_port: downstreamCoordinate)
        )
    }
}

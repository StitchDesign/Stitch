//
//  EdgeEditingActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/31/24.
//

import StitchSchemaKit
import SwiftUI

struct OutputHoveredLongEnough: GraphEvent {
    func handle(state: GraphState) {
        // log("OutputHoveredLongEnough called")
        // does nothing if no edge-editing-state ?
        state.edgeEditingState?.labelsShown = true
    }
}

extension GraphState {

    @MainActor
    func outputHovered(outputCoordinate: OutputPortIdAddress,
                       groupNodeFocused: NodeId?) {
        // log("outputHovered fired")
        
        guard let graphMovement = self.documentDelegate?.graphMovement else {
            fatalErrorIfDebug()
            return
        }
        
        if self.edgeDrawingObserver.drawingGesture != nil {
            // log("OutputHovered called during edge drawing gesture; exiting")
            self.edgeAnimationEnabled = false
            self.edgeEditingState = nil
            return
        }
        
        if graphMovement.canvasItemIsDragged || self.nodeIsMoving {
            // log("OutputHovered called during node drag; exiting")
            self.edgeAnimationEnabled = false
            self.edgeEditingState = nil
            return
        }
                
        guard let nodesEastOfOutput = self
            .getNodesToTheEastFromClosestToFarthest(eastOf: outputCoordinate.canvasId,
                                                    groupNodeFocused: groupNodeFocused) else {
            // log("OutputHovered: no nodes to the east of this hovered output")
            // This is okay; it can happen that there are no nodes east of this node
            return
        }
        
        guard let nearbyNodeId = nodesEastOfOutput[safeIndex: EdgeEditingState.defaultNearbyCanvasItemIndex] else {
            // log("OutputHovered: could not retrieve closest nearby-node")
            fatalErrorIfDebug()
            return
        }
                
        guard let nearbyNode = self.getCanvasItem(nearbyNodeId) else {
            // log("OutputHovered: could not retrieve nearby node \(nearbyNodeId)")
            return
        }
        
        // log("OutputHovered: nearbyNodeId: \(nearbyNodeId)")
        let (alreadyShownEdges,
             possibleEdges) = getShownAndPossibleEdges(nearbyNode: nearbyNode,
                                                       outputCoordinate: outputCoordinate,
                                                       groupNodeFocused: groupNodeFocused)
        
        // log("OutputHovered: possibleEdges: \(possibleEdges)")
        // log("OutputHovered: alreadyShownEdges: \(alreadyShownEdges)")
        
        self.edgeAnimationEnabled = true
                
        self.edgeEditingState = .init(
            originOutput: outputCoordinate,
            eastNodesFromClosestToFarthest: nodesEastOfOutput,
            nearbyCanvasItemIndex: EdgeEditingState.defaultNearbyCanvasItemIndex,
            possibleEdges: possibleEdges,
            shownIds: alreadyShownEdges)
    }
    
    @MainActor
    func getShownAndPossibleEdges(nearbyNode: CanvasItemViewModel,
                                  outputCoordinate: OutputPortIdAddress,
                                  groupNodeFocused: NodeId?) -> (shownEdges: Set<PossibleEdgeId>,
                                            possibleEdges: PossibleEdgeSet) {
        var alreadyShownEdges = Set<PossibleEdgeId>()
        
        // log("getShownAndPossibleEdges: nearbyNode.id: \(nearbyNode.id)")
        
        let possibleEdges: PossibleEdgeSet = nearbyNode
        
            .edgeFriendlyInputCoordinates(from: self.visibleNodesViewModel,
                                          focusedGroupId: groupNodeFocused)
        
            .reduce(into: PossibleEdgeSet()) { partialResult, inputCoordinate in
                // log("getShownAndPossibleEdges: on inputCoordinate: \(inputCoordinate)")
                                
                let edgeUI = PortEdgeUI(from: outputCoordinate,
                                        to: inputCoordinate)
                
                guard let edgeData = PortEdgeData(viewData: edgeUI, graph: self) else {
                    return
                }
                
                /*
                 If there's already an edge to this input,
                 then start out with the possible-edge committed.
                 Note: `graphSchema.connections.hasEdge` checks whether the input has any edges, not this specific edge
                 */
                let isCommitted = self.edgeExists(edgeData)
                
                let possibleEdge = PossibleEdge(
                    edge: edgeUI,
                    isCommitted: isCommitted)
                
                if isCommitted {
                    alreadyShownEdges.insert(possibleEdge.id)
                }
                
                partialResult.insert(possibleEdge)
            }
        
        // log("getShownAndPossibleEdges: alreadyShownEdges: \(alreadyShownEdges)")
        // log("getShownAndPossibleEdges: possibleEdges: \(possibleEdges)")
        
        return (shownEdges: alreadyShownEdges,
                possibleEdges: possibleEdges)
    }
}


extension CanvasItemViewModel {
    
    // Get the "edge-friendly" coordinates,
    // i.e. the real input coords for a non-group node,
    // or the input-splitter coords for a group node.
    @MainActor
    func edgeFriendlyInputCoordinates(from nodes: VisibleNodesViewModel,
                                      focusedGroupId: NodeId?) -> [InputPortIdAddress] {
        
        // this looks at ALL nodes' inputs -- need to look only at
        
        nodes.getCanvasItemsAtTraversalLevel(at: focusedGroupId)
            .flatMap { canvasItem -> [InputPortIdAddress] in
                
                // TODO: just retrieve the node from nodes, `nodes.get`
                guard let nodeId = self.nodeDelegate?.id,
                      let canvasItemNodeId = canvasItem.nodeDelegate?.id,
                      nodeId == canvasItemNodeId else {
                    // log("edgeFriendlyInputCoordinates: canvas item was not for this node")
                    return .init()
                }
                
                let inputsCount = canvasItem.inputViewModels.count
                return (0..<inputsCount).map {
                    InputPortIdAddress(portId: $0, canvasId: canvasItem.id)
                }
            }
    }
}

extension GraphState {
    /// Determines if there's an existing edge based on cached `Connections` data.
    @MainActor
    func edgeExists(_ edge: PortEdgeData) -> Bool {
        self.connections.get(edge.from)?.contains(edge.to) ?? false
    }
}

struct OutputHoverEnded: GraphEvent {
    
    func handle(state: GraphState) {
        // log("OutputHoverEnded called")
        state.edgeEditingState = nil
        state.edgeAnimationEnabled = false
    }
}

struct PossibleEdgeCommitmentCompleted: ProjectEnvironmentEvent {
    
    let possibleEdgeId: PossibleEdgeId
    let edge: PortEdgeUI
    
    func handle(graphState: GraphState,
                environment: StitchEnvironment) -> GraphResponse {
        
        log("PossibleEdgeCommitmentCompleted: possibleEdgeId: \(possibleEdgeId)")
        log("PossibleEdgeCommitmentCompleted: edge: \(edge)")
        
        graphState.edgeEditingState?.animationInProgressIds.remove(possibleEdgeId)
        
        graphState.edgeAdded(
            edge: edge)
        
        return .persistenceResponse
    }
}

struct PossibleEdgeDecommitmentCompleted: GraphEvent {
    
    let possibleEdgeId: PossibleEdgeId
    let edge: PortEdgeUI
    let activeIndex: ActiveIndex
    
    func handle(state: GraphState) {
        
        // log("PossibleEdgeDecommitmentCompleted: possibleEdgeId: \(possibleEdgeId)")
        // log("PossibleEdgeDecommitmentCompleted: edge: \(edge)")
        
        state.edgeEditingState?.animationInProgressIds.remove(possibleEdgeId)
        state.edgeEditingState?.shownIds.remove(possibleEdgeId)
        
        state.removeEdgeAt(input: edge.to)
        
        state.encodeProjectInBackground()
    }
}

extension GraphState {
    
    @MainActor
    func getNodesToTheEastFromClosestToFarthest(eastOf originOutputNodeId: CanvasItemId,
                                                groupNodeFocused: NodeId?) -> EligibleEasternNodes? {
        
        guard let originOutputNode = self.getCanvasItem(originOutputNodeId) else {
            log("getNodesToTheEastFromClosestToFarthest: node not found: \(originOutputNodeId)")
            return nil
        }
        
        guard let hoveredOutputLocation: CGPoint = originOutputNode.locationOfOutputs else {
            log("getNodesToTheEastFromClosestToFarthest: output hovered node does not have size: \(originOutputNodeId)")
            return nil
        }
        
        // log("getNodesToTheEastFromClosestToFarthest: for originOutputNode \(originOutputNode.id), hoveredOutputLocation: \(hoveredOutputLocation)")
                
        let nodes = self.visibleNodesViewModel
            .getCanvasItemsAtTraversalLevel(at: groupNodeFocused)
            .filter { node in
                // "Nearby node" for edge-edit mode can never be a wireless receiver node
                node.nodeDelegate?.kind.getPatch != .wirelessReceiver
                
                // Exclude the output-hovered node itself
                && node.id != originOutputNode.id
            }
        
        // Note: we compare the origin node's output against the other nodes' inputs.
        // The *input* must be east of the output.
        let nodesEast = nodes.filter { node in
            /*
             Note: although SwiftUI's .position modifier is from top-left corner, we actually adjust the node's `position: CGPoint`, such that position = center of node.
             
             So:
             `node.center.x - node.width/2` = east face, where inputs are.
             `node.center.x + node.width/2` = west face, where outputs are.
             */
            guard let inputLocation = node.locationOfInputs else {
                return false
            }
            
            return inputLocation.x > hoveredOutputLocation.x
        }
        
        guard !nodesEast.isEmpty else {
            log("getNodesToTheEastFromClosestToFarthest: no nodes to the east of this output")
            return nil
        }
                
        let sortedNodes = nodesEast.sorted { n1, n2 in
            let distance1 = hoveredOutputLocation.distance(to: n1.locationOfInputs ?? .zero)
            let distance2 = hoveredOutputLocation.distance(to: n2.locationOfInputs ?? .zero)
            return distance1 < distance2
        }.map(\.id)
        
        // log("getNodesToTheEastFromClosestToFarthest: \(sortedNodes)")
        
        guard let result = EligibleEasternNodes(sortedNodes) else {
            log("getNodesToTheEastFromClosestToFarthest: could not create non-empty array")
            return nil
        }
        
        return result
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow((point.x - x), 2) + pow((point.y - y), 2))
    }
}

extension VisibleNodesViewModel {
    @MainActor
    func nodePageDataAtThisTraversalLevel(_ focusedGroup: NodeId?) -> NodePageData? {
        self.nodesByPage.get(focusedGroup.map(NodePageType.group) ?? NodePageType.root)
    }
}

extension GraphState {
    @MainActor
    func keyCharPressedDuringEdgeEditingMode(char: Character, activeIndex: ActiveIndex) {
        
        let graph = self
        
        guard let labelPresssed = EdgeEditingModeInputLabel.fromKeyCharacter(char) else {
            log("keyCharPressedDuringEdgeEditingMode: char pressed \(char) did not map to any supported edge-edit-mode input label")
            return
        }
        
        // log("keyCharPressedDuringEdgeEditingMode: labelPresssed: \(labelPresssed)")
        
        // Should never happen
        guard let edgeEditingState = graph.edgeEditingState else {
            log("keyCharPressedDuringEdgeEditingMode: called without edgeEditingState")
            return
        }
        
        guard let nearbyCanvasItem = graph.getCanvasItem(edgeEditingState.nearbyCanvasItem) else {
            log("keyCharPressedDuringEdgeEditingMode: could not retrieve \(edgeEditingState.nearbyCanvasItem)")
            return
        }
        
        if let patch = graph.getPatchNode(id: nearbyCanvasItem.id.nodeId)?.patch,
           patch.inputsDisabled {
            log("keyCharPressedDuringEdgeEditingMode: cannot create an edge to a disabled input")
           return
        }
        
        let labelAsPortId = labelPresssed.toPortId // i.e. port index
        // log("keyCharPressedDuringEdgeEditingMode: labelAsPortId: \(labelAsPortId)")
        
        let destinationInput = InputPortIdAddress(portId: labelAsPortId, canvasId: nearbyCanvasItem.id)
        
        //    let destinationInput = nearbyNode.groupNode?.splitterInputs[safe: labelAsPortId]?.rowObserver?.id ?? .init(portId: labelAsPortId, nodeId: nearbyNode.id)
        
        // log("keyCharPressedDuringEdgeEditingMode: destinationInput: \(destinationInput)")
        
        let edge = PortEdgeUI(from: edgeEditingState.originOutput,
                              to: destinationInput)
        
        let thisPossibleEdge = edgeEditingState.possibleEdges.first { $0.edge == edge }
        
        // Should never happen; we should ALWAYS have ALL possible edges;
        // difference is merely in whether the edge is shown or not, etc.
        guard var thisPossibleEdge = thisPossibleEdge else {
            log("keyCharPressedDuringEdgeEditingMode: did not have possibleEdge for edge \(edge)")
            return
        }
        
        // If we're currently animating this possible edge (i.e. extending or withdrawing it),
        // then ignore this key press.
        guard !edgeEditingState.animationInProgressIds.contains(thisPossibleEdge.id) else {
            // log("keyCharPressedDuringEdgeEditingMode: currently animated possibleEdge \(thisPossibleEdge.id), so will ignore key press \(char)")
            return
        }
        
        // log("keyCharPressedDuringEdgeEditingMode: edge: \(edge)")
        // log("keyCharPressedDuringEdgeEditingMode: thisPossibleEdge: \(thisPossibleEdge)")
        // log("keyCharPressedDuringEdgeEditingMode: edgeEditingState.possibleEdges was: \(edgeEditingState.possibleEdges)")
        // log("keyCharPressedDuringEdgeEditingMode: edgeEditingState.animationInProgressIds was: \(edgeEditingState.animationInProgressIds)")
        
        // If edge is already committed, then de-commit it.
        if thisPossibleEdge.isCommitted {
            
            // log("keyCharPressedDuringEdgeEditingMode: will remove edge")
            
            // Immediately add the possible-edge-id to animationInProgressIds
            graph.edgeEditingState?.animationInProgressIds.insert(thisPossibleEdge.id)
            
            // Immediately remove the existing edge
            // TODO: why does this still leave the existing edge looking like it's still existing?
            // graph.removeEdgeAt(input: edge.to)
            
            // Animate the withdrawal
            withAnimation(.linear(duration: .POSSIBLE_EDGE_ANIMATION_DURATION)) {
                log("removal animation started")
                
                // insert a new version that is not committed
                let filtered = graph.edgeEditingState?.possibleEdges.filter {
                    $0.id != thisPossibleEdge.id
                } ?? .init()
                
                graph.edgeEditingState?.possibleEdges = filtered
                thisPossibleEdge.isCommitted = false
                graph.edgeEditingState?.possibleEdges.insert(thisPossibleEdge)
            } completion: {
                log("removal animation completed")
                // On animation completion, hide the edge and remove it from 'currently animating'
                // NOTE: we also redundantly remove the edge again; helps with key spamming.
                dispatch(PossibleEdgeDecommitmentCompleted(
                    possibleEdgeId: thisPossibleEdge.id,
                    edge: edge,
                    activeIndex: activeIndex))
            }
        }
        
        // If edge is not already committed, then commit it.
        else {
            // log("keyCharPressedDuringEdgeEditingMode: will add edge")
            
            // immediately update the StitchDocumentViewModel's edge editing state to include the shown edge
            graph.edgeEditingState?.shownIds.insert(thisPossibleEdge.id)
            graph.edgeEditingState?.animationInProgressIds.insert(thisPossibleEdge.id)
            
            withAnimation(.linear(duration: .POSSIBLE_EDGE_ANIMATION_DURATION)) {
                log("addition animation started")
                
                // setting isCommitted=true for this edge; triggers the change of the `to` from the origin to the destination
                let filtered = graph.edgeEditingState?.possibleEdges.filter {
                    $0.id != thisPossibleEdge.id
                } ?? .init()
                graph.edgeEditingState?.possibleEdges = filtered
                thisPossibleEdge.isCommitted = true
                graph.edgeEditingState?.possibleEdges.insert(thisPossibleEdge)
            } completion: {
                // log("addition animation completed")
                // we're done animating
                
                // add the edge to GraphSchema
                
                // this completion handler style conflicts a bit with
                dispatch(PossibleEdgeCommitmentCompleted(possibleEdgeId: thisPossibleEdge.id,
                                                         edge: edge))
            }
        } // else
        
        self.removeEdgeAt(input: edge.to)
    }
}

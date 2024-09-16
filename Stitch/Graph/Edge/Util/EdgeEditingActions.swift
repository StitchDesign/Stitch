//
//  EdgeEditingActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/31/24.
//

import StitchSchemaKit
import SwiftUI

struct OutputHoveredLongEnough: GraphUIEvent {
    func handle(state: GraphUIState) {
        // log("OutputHoveredLongEnough called")
        // does nothing if no edge-editing-state ?
        state.edgeEditingState?.labelsShown = true
    }
}

extension GraphState {
    @MainActor
    func outputHovered(outputCoordinate: OutputPortViewData) {
        
        if self.edgeDrawingObserver.drawingGesture != nil {
            log("OutputHovered called during edge drawing gesture; exiting")
            self.graphUI.edgeAnimationEnabled = false
            self.graphUI.edgeEditingState = nil
            return
        }

        if self.graphMovement.canvasItemIsDragged || self.nodeIsMoving {
            log("OutputHovered called during node drag; exiting")
            self.graphUI.edgeAnimationEnabled = false
            self.graphUI.edgeEditingState = nil
            return
        }

        guard let nearbyNodeId = self.getEligibleNearbyNode(eastOf: outputCoordinate.canvasId) else {
            log("OutputHovered: no nearby node")
            return
        }

        guard let nearbyNode = self.getCanvasItem(nearbyNodeId) else {
            log("OutputHovered: could not retrieve nearby node \(nearbyNodeId)")
            return
        }

        // log("OutputHovered: nearbyNodeId: \(nearbyNodeId)")

        var alreadyShownEdges = Set<PossibleEdgeId>()

        let possibleEdges: PossibleEdgeSet = nearbyNode
            .edgeFriendlyInputCoordinates(from: self.visibleNodesViewModel,
                                          focusedGroupId: self.groupNodeFocused)
            .reduce(into: PossibleEdgeSet()) { partialResult, inputCoordinate in

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

        // log("OutputHovered: possibleEdges: \(possibleEdges)")
        // log("OutputHovered: alreadyShownEdges: \(alreadyShownEdges)")

        self.graphUI.edgeAnimationEnabled = true

        self.graphUI.edgeEditingState = .init(
            originOutput: outputCoordinate,
            nearbyCanvasItem: nearbyNodeId,
            possibleEdges: possibleEdges,
            shownIds: alreadyShownEdges)
    }
}

extension CanvasItemViewModel {

    // Get the "edge-friendly" coordinates,
    // i.e. the real input coords for a non-group node,
    // or the input-splitter coords for a group node.
    @MainActor
    func edgeFriendlyInputCoordinates(from nodes: VisibleNodesViewModel,
                                      focusedGroupId: NodeId?) -> [InputPortViewData] {
        nodes.getVisibleCanvasItems(at: focusedGroupId)
            .flatMap { canvasItem in
                let inputsCount = canvasItem.inputViewModels.count
                return (0..<inputsCount).map {
                    InputPortViewData(portId: $0, canvasId: canvasItem.id)
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
        state.graphUI.edgeEditingState = nil
        state.graphUI.edgeAnimationEnabled = false
    }
}

struct PossibleEdgeCommitmentCompleted: ProjectEnvironmentEvent {

    let possibleEdgeId: PossibleEdgeId
    let edge: PortEdgeUI

    func handle(graphState: GraphState,
                environment: StitchEnvironment) -> GraphResponse {

        log("PossibleEdgeCommitmentCompleted: possibleEdgeId: \(possibleEdgeId)")
        log("PossibleEdgeCommitmentCompleted: edge: \(edge)")

        graphState.graphUI.edgeEditingState?.animationInProgressIds.remove(possibleEdgeId)

        graphState.edgeAdded(
            edge: edge)

        return .persistenceResponse
    }
}

struct PossibleEdgeDecommitmentCompleted: GraphEvent {

    let possibleEdgeId: PossibleEdgeId
    let edge: PortEdgeUI

    func handle(state: GraphState) {

        // log("PossibleEdgeDecommitmentCompleted: possibleEdgeId: \(possibleEdgeId)")
        // log("PossibleEdgeDecommitmentCompleted: edge: \(edge)")

        state.graphUI.edgeEditingState?.animationInProgressIds.remove(possibleEdgeId)
        state.graphUI.edgeEditingState?.shownIds.remove(possibleEdgeId)

        state.removeEdgeAt(input: edge.to)
    }
}

extension GraphState {

    @MainActor
    func getEligibleNearbyNode(eastOf originOutputNodeId: CanvasItemId) -> CanvasItemId? {

        guard let originOutputNode = self.getCanvasItem(originOutputNodeId) else {
            log("GraphState.closesNodeEast: node not found: \(originOutputNodeId)")
            return nil
        }

        let groupNodeFouced = self.graphUI.groupNodeFocused?.asNodeId
        let nodes = self.visibleNodesViewModel
            .getVisibleCanvasItems(at: groupNodeFouced)
            // "Nearby node" for edge-edit mode can never be a wireless receiver node
            .filter { $0.nodeDelegate?.kind.getPatch != .wirelessReceiver }

        // Note: we compare the origin node's output against the other nodes' inputs.
        // The *input* must be east of the output.
        let nodesEast = nodes.filter { node in
            /*
             Note: although SwiftUI's .position modifier is from top-left corner, we actually adjust the node's `position: CGPoint`, such that position = center of node.

             So:
             `node.center.x - node.width/2` = east face, where inputs are.
             the `node.center.x + node.width/2` = west face, where outputs are.
             */
            let adjustedOrigin = originOutputNode.position.x + originOutputNode.sizeByLocalBounds.width/2
            let adjustedInput = node.position.x - node.sizeByLocalBounds.width/2
            return adjustedInput > adjustedOrigin
        }

        return nodesEast.min { n1, n2 in
            let distance1 = originOutputNode.position.distance(to: n1.position)
            let distance2 = originOutputNode.position.distance(to: n2.position)
            return distance1 < distance2
        }?.id
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow((point.x - x), 2) + pow((point.y - y), 2))
    }
}

extension VisibleNodesViewModel {

    func nodePageDataAtCurrentTraversalLevel(_ focusedGroup: GroupNodeId?) -> NodePageData? {
        self.nodesByPage.get(focusedGroup.map(NodePageType.group) ?? NodePageType.root)
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func keyCharPressedDuringEdgeEditingMode(char: Character) {
        
        guard let labelPresssed = EdgeEditingModeInputLabel.fromKeyCharacter(char) else {
            log("keyCharPressedDuringEdgeEditingMode: char pressed \(char) did not map to any supported edge-edit-mode input label")
            return
        }
        
        // log("keyCharPressedDuringEdgeEditingMode: labelPresssed: \(labelPresssed)")
        
        // Should never happen
        guard let edgeEditingState = self.graphUI.edgeEditingState else {
            log("keyCharPressedDuringEdgeEditingMode: called without edgeEditingState")
            return
        }
        
        guard let nearbyNode = self.visibleGraph.getCanvasItem(edgeEditingState.nearbyCanvasItem) else {
            log("keyCharPressedDuringEdgeEditingMode: could not retrieve \(edgeEditingState.nearbyCanvasItem)")
            return
        }
        
        let labelAsPortId = labelPresssed.toPortId // i.e. port index
        // log("keyCharPressedDuringEdgeEditingMode: labelAsPortId: \(labelAsPortId)")
        
        let destinationInput = InputPortViewData(portId: labelAsPortId, canvasId: nearbyNode.id)
        
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
            self.graphUI.edgeEditingState?.animationInProgressIds.insert(thisPossibleEdge.id)
            
            // Animate the withdrawal
            withAnimation(.linear(duration: .POSSIBLE_EDGE_ANIMATION_DURATION)) {
                // log("removal animation started")
                
                // insert a new version that is not committed
                self.graphUI.edgeEditingState?.possibleEdges = self.graphUI.edgeEditingState?.possibleEdges.filter {
                    $0.id != thisPossibleEdge.id
                } ?? .init()
                thisPossibleEdge.isCommitted = false
                self.graphUI.edgeEditingState?.possibleEdges.insert(thisPossibleEdge)
            } completion: {
                // log("removal animation completed")
                // On animation completion, hide the edge and remove it from 'currently animating'
                // NOTE: we also redundantly remove the edge again; helps with key spamming.
                dispatch(PossibleEdgeDecommitmentCompleted(
                    possibleEdgeId: thisPossibleEdge.id,
                    edge: edge))
            }
        }
        
        // If edge is not already committed, then commit it.
        else {
            // log("keyCharPressedDuringEdgeEditingMode: will add edge")
            
            // immediately update the graphUIState's edge editing state to include the shown edge
            self.graphUI.edgeEditingState?.shownIds.insert(thisPossibleEdge.id)
            self.graphUI.edgeEditingState?.animationInProgressIds.insert(thisPossibleEdge.id)
            
            withAnimation(.linear(duration: .POSSIBLE_EDGE_ANIMATION_DURATION)) {
                // log("addition animation started")
                
                // setting isCommitted=true for this edge; triggers the change of the `to` from the origin to the destination
                self.graphUI.edgeEditingState?.possibleEdges = self.graphUI.edgeEditingState?.possibleEdges.filter {
                    $0.id != thisPossibleEdge.id
                } ?? .init()
                thisPossibleEdge.isCommitted = true
                self.graphUI.edgeEditingState?.possibleEdges.insert(thisPossibleEdge)
                
                // log("keyCharPressedDuringEdgeEditingMode: graphState.graphUI.edgeEditingState?.possibleEdges is now: \(graphState.graphUI.edgeEditingState?.possibleEdges)")
                
            } completion: {
                // log("addition animation completed")
                // we're done animating
                //            graphState.graphUI.edgeEditingState?.animationInProgressIds.remove(thisPossibleEdge.id)
                
                // add the edge to GraphSchema
                
                // this completion handler style conflicts a bit with
                dispatch(PossibleEdgeCommitmentCompleted(possibleEdgeId: thisPossibleEdge.id,
                                                         edge: edge))
            }
        }

        return self.visibleGraph.removeEdgeAt(input: edge.to)
    }
}

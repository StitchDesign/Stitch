//
//  GraphUIScrollActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/17/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphState {
    // this is 'graph panned via screen finger'
    @MainActor
    func graphDragged(translation: CGSize,
                      location: CGPoint,
                      document: StitchDocumentViewModel) {
        // Always set current drag location
        self.selection.dragCurrentLocation = location
        
        if self.edgeEditingState != nil {
            self.edgeEditingState = nil
        }

        // Active node selection cursor
        if self.selection.isSelecting {
            self.handleGraphDraggedDuringSelection(
                location)
            return
        } else {
            self.handleGraphScrollWithBorders(
                gestureTranslation: translation,
                wasTrackpadScroll: false,
                document: document)
        }
    }

    /// Places important role in only enabling graph dragging when certain actions kick off.
    /// This system permits easy cancelling of graph dragging if higher priority gestures (like graph selection)
    /// take place.
    @MainActor
    func graphScrollBegan() {
        self.selection.graphDragState = .dragging
        
        if self.edgeEditingState != nil {
            self.edgeEditingState = nil
        }
    }

    // Pans graph with two-finger trackpad gesture;
    // distinct from GraphDragged because cannot trigger a long-press.
    @MainActor
    func graphScrolled(translation: CGPoint,
                       wasTrackpadScroll: Bool = false,
                       document: StitchDocumentViewModel) {
        self.handleGraphScrollWithBorders(
            gestureTranslation: translation.toCGSize,
            wasTrackpadScroll: wasTrackpadScroll,
            document: document)
    }
}

struct GraphDraggedDuringSelection: GraphEvent {
    
    let location: CGPoint
    
    func handle(state: GraphState) {
        
        // added:
        // Always set current drag location
        state.selection.dragCurrentLocation = location
        
        // added: called by `graphScrollBegan
        state.selection.graphDragState = .dragging
        
        if state.edgeEditingState != nil {
            state.edgeEditingState = nil
        }
        
        state.handleGraphDraggedDuringSelection(location)
    }
}

extension GraphState {
    @MainActor
    func handleGraphDraggedDuringSelection(_ gestureLocation: CGPoint) {
        guard let gestureStartLocation = self.selection.dragStartLocation else {
            log("GraphState.handleGraphDraggedDuringSelection: no start location")
            return
        }
        
        
//        var box = self.selection.expansionBox ?? .init(origin: gestureStartLocation, size: .zero)

//        let size = CGSize(width: gestureLocation.x - gestureStartLocation.x,
//                          height: gestureLocation.y - gestureStartLocation.y)
//        box.size = size
        
        var box = self.selection.expansionBox ?? .init()
        box.startPoint = gestureStartLocation
        
        let (newSize, newDirection) = trigCalc(
            start: gestureStartLocation,
            end: gestureLocation
        )
        
        box.size = newSize
        box.expansionDirection = newDirection
        box.endPoint = gestureLocation
        
        self.selection.expansionBox = box
    }

    @MainActor
    func handleGraphScrolled(_ translation: CGSize,
                             wasTrackpadScroll: Bool,
                             document: StitchDocumentViewModel) {

        // Scrolling the graph immediately exits edge-editing state and disables edge-animation
        // setOnChange needed to prevent extra render cycles
        if self.edgeEditingState != nil {
            self.edgeEditingState = nil
        }

        if self.edgeAnimationEnabled {
            self.edgeAnimationEnabled = false
        }

        // End dragging if some event (i.e. graph tap) happened
        guard self.selection.graphDragState == .dragging else {
            log("handleGraphScrolled: ended due to cancelled dragging from other event.")
            self.graphDragEnded(location: nil,
                                velocity: .zero,
                                wasScreenDrag: false,
                                frame: document.frame)
            return
        }

        //    log("handleGraphScrolled: state.graphMovement.localPosition was: \(state.graphMovement.localPosition)")
//
//        //    log("handleGraphScrolled: translation was: \(translation)")
//
//        // Always update the graph offset,
//        // regardless whether there is another active gesture.
//        self.graphMovement.localPosition = self.localPreviousPosition + (translation.toCGPoint / self.graphMovement.zoomData)

        //    log("handleGraphScrolled: state.graphMovement.localPosition is now: \(state.graphMovement.localPosition)")

//        self.graphMovement.runningGraphTranslation = translation

        // DUAL DRAG:

//        if !self.graphMovement.graphIsDragged {
//            self.graphMovement.graphIsDragged = true
//        }

        guard let graphMovement = self.documentDelegate?.graphMovement else {
            fatalErrorIfDebug()
            return
        }
        
        // If we don't have an active first gesture,
        // and node isn't already dragging,
        // then set graph-drag as active first gesture
        if graphMovement.firstActive == .none {
            if !graphMovement.canvasItemIsDragged {
                log("graphDrag onChanged: will set .graph as active first gesture")
                graphMovement.firstActive = .graph
            }
        }

        graphMovement.runningGraphTranslation = translation

        // If we're simultaneously dragging the node,
        // add inverse graph translation to node's position,
        // so that node stays under our finger:
        if graphMovement.canvasItemIsDragged {

            self.getSelectedCanvasItems(groupNodeFocused: document.groupNodeFocused?.groupNodeId)
                .forEach { node in
            // self.getSelectedNodeViewModels().forEach { node in
                node.updateNodeOnGraphDragged(
                    translation,
                    self.highestZIndex + 1,
                    zoom: graphMovement.zoomData,
                    state: graphMovement)
            }

            //    log("handleGraphScrolled: state.graphMovement.localPosition is now: \(state.graphMovement.localPosition)")
        }
        
        graphMovement.wasTrackpadScroll = wasTrackpadScroll
    }

    // `handleGraphScrolled` is kept relatively pure and separate;
    // but in many drag cases we need to do border checks (graph min/max),
    // so here we do that prep-work:

    // nil = no prep work to be done; ie we didn't hit any borders yet
    @MainActor
    func handleGraphScrollWithBorders(gestureTranslation: CGSize,
                                      wasTrackpadScroll: Bool,
                                      document: StitchDocumentViewModel) {

        // SEE GITHUB ISSUE ABOUT OPTIMIZING BORDER-CHECKING FOR LARGE GRAPHS:
        // https://github.com/vpl-codesign/stitch/issues/2469
        self.handleGraphScrolled(
            gestureTranslation,
            wasTrackpadScroll: wasTrackpadScroll,
            document: document)
    }
}

extension StitchDocumentViewModel {
    @MainActor
    var localPositionToPersist: CGPoint {
        
        return ABSOLUTE_GRAPH_CENTER
        
//        /*
//         TODO: serialize graph-offset by traversal level; introduce centroid/find-node button
//         
//         Ideally, we remember (serialize) each traversal level's graph-offset.
//         Currently, we only remember the root level's graph-offset.
//         So if we were inside a group, we save not the group's graph-offset (graphState.localPosition), but the root graph-offset
//         */
//        
//        // log("GraphState.localPositionToPersists: self.localPosition: \(self.localPosition)")
//        
//        let _rootLevelGraphOffset = self.visibleGraph
//            .visibleNodesViewModel
//            .nodePageDataAtCurrentTraversalLevel(nil)?
//            .localPosition
//        
//        if !_rootLevelGraphOffset.isDefined {
//            log("GraphState.localPositionToPersists: no root level graph offset")
//        }
//        
//        let rootLevelGraphOffset = _rootLevelGraphOffset ?? ABSOLUTE_GRAPH_CENTER
//        
//        let graphOffset = self.groupNodeFocused.isDefined ? rootLevelGraphOffset : self.localPosition
//        
//        // log("GraphState.localPositionToPersists: rootLevelGraphOffset: \(rootLevelGraphOffset)")
//        // log("GraphState.localPositionToPersists: graphOffset: \(graphOffset)")
//        
//        // TODO: factor out zoom level
//        
//        let scale = self.graphMovement.zoomData
//        
//        // UIScrollView's contentOffset is based on contentSize, which is a function zoomScale;
//        // but we do not persist zoom;
//        // so, we factor out the effect of zoom on contentOffset.
//        let scaledGraphOffset = CGPoint(x: graphOffset.x * 1/scale,
//                                        y: graphOffset.y * 1/scale)
//        
//        // log("GraphState.localPositionToPersists: scale: \(scale)")
//        // log("GraphState.localPositionToPersists: scaledGraphOffset: \(scaledGraphOffset)")
//        
//        return scaledGraphOffset
    }
    
    @MainActor
    var localPosition: CGPoint {
        get {
            return self.graphMovement.localPosition
        } set {
            self.graphMovement.localPosition = newValue
        }
    }
    
    @MainActor
    var localPreviousPosition: CGPoint {
        get {
            self.graphMovement.localPreviousPosition
        } set {
            self.graphMovement.localPreviousPosition = newValue
        }
    }
}

extension GraphState {
    @MainActor
    func handleTrackpadGraphDragEnded() {

        //    log("handleTrackpadGraphDragEnded called")

        guard let graphMovement = self.documentDelegate?.graphMovement else {
            fatalErrorIfDebug()
            return
        }
        
        // DO NOT reset selected nodes themselves
        self.selection.expansionBox = nil
        self.selection.isSelecting = false
        self.selection.dragStartLocation = nil
        self.selection.dragCurrentLocation = nil

        // always reset 'wasTrackpadScroll'
        graphMovement.wasTrackpadScroll = false

        graphMovement.draggedCanvasItem = nil
        
        // Reset shift+click drag selections
        self.nodesAlreadySelectedAtStartOfShiftNodeCursorBoxDrag = nil
    }

    // you should pass in GraphMovement
    @MainActor
    func graphDragEnded(location: CGPoint?,
                        velocity: CGPoint,
                        wasScreenDrag: Bool,
                        frame: CGRect) {

        guard let graphMovement = self.documentDelegate?.graphMovement else {
            fatalErrorIfDebug()
            return
        }

        // always set start and current location of drag gesture
        self.selection.dragStartLocation = nil

        if location.isDefined {
            self.selection.dragCurrentLocation = nil
        }

        self.selection.expansionBox = nil
        self.selection.isSelecting = false

        //    log("handleGraphDragEnded: state.graphMovement.localPreviousPosition was \(state.graphMovement.localPreviousPosition)")
        //    log("handleGraphDragEnded: state.graphMovement.localPosition was \(state.graphMovement.localPosition)")

        // NORMAL:

        graphMovement.localPreviousPosition = graphMovement.localPosition

        // DUAL DRAG:

        if graphMovement.graphIsDragged {
            graphMovement.graphIsDragged = false            
        }

        // Only add to `accumulated` if we're indeed dragging at least one node
        if graphMovement.canvasItemIsDragged {
            graphMovement.accumulatedGraphTranslation += (graphMovement.runningGraphTranslation ?? .zero) / graphMovement.zoomData
        }

        graphMovement.runningGraphTranslation = nil

        if graphMovement.canvasItemIsDragged {
            //        log("graphDrag: onEnded: will set .graph as active first gesture")
            graphMovement.firstActive = .node
        } else {
            //        log("graphDrag: onEnded: will set .none as active first gesture")
            graphMovement.firstActive = .none
        }

        //    log("handleGraphDragEnded: momentumOrigin: \(momentumOrigin)")

        // always reset 'wasTrackpadScroll'
        graphMovement.wasTrackpadScroll = false

        // Wipe comment box bounds
        self.wipeCommentBoxBounds()

        // Cancel any possible active graph pan gesture
        self.selection.graphDragState = .none
        
        // Reset shift-click selection state
        self.nodesAlreadySelectedAtStartOfShiftNodeCursorBoxDrag = nil
    }
}

extension GraphState {
    @MainActor
    func wipeCommentBoxBounds() {
        self.commentBoxBoundsDict = .init()
    }
}

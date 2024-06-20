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
                      location: CGPoint) {
        // Always set current drag location
        self.graphUI.selection.dragCurrentLocation = location
        
        if self.graphUI.edgeEditingState != nil {
            self.graphUI.edgeEditingState = nil
        }

        // Active node selection cursor
        if self.graphUI.selection.isSelecting {
            self.handleGraphDraggedDuringSelection(
                location)
            return
        } else {
            self.handleGraphScrollWithBorders(
                gestureTranslation: translation,
                wasTrackpadScroll: false)
        }
    }

    /// Places important role in only enabling graph dragging when certain actions kick off.
    /// This system permits easy cancelling of graph dragging if higher priority gestures (like graph selection)
    /// take place.
    @MainActor
    func graphScrollBegan() {
        self.graphUI.selection.graphDragState = .dragging
        
        if self.graphUI.edgeEditingState != nil {
            self.graphUI.edgeEditingState = nil
        }
    }

    // Pans graph with two-finger trackpad gesture;
    // distinct from GraphDragged because cannot trigger a long-press.
    @MainActor
    func graphScrolled(translation: CGPoint,
                       wasTrackpadScroll: Bool = false) {
        self.handleGraphScrollWithBorders(
            gestureTranslation: translation.toCGSize,
            wasTrackpadScroll: wasTrackpadScroll)
    }

    /// Fixes issue where tap gestures need to be registered in UKit to stop a graph jumpiness bug.
    /// Tapping the graph should stop momentum.
    @MainActor
    func graphTappedDuringMouseScroll() {
        log("GraphTappedDuringMouseScroll called")
        self.graphMovement.resetGraphMovement()
        self.graphUI.selection.graphDragState = .none
    }
}

extension GraphMovementObserver {
    // called when a graph drag handler fires;
    // returns (actualTranslationForThisDimension,
    //          updatedGraphUIState)
    @MainActor
    func borderHelperX(gestureTranslation: CGSize,
                       easternMostNodeX: CGFloat,
                       frame: CGRect,
                       graphBounds: CGRect,
                       startOrigins: CGPoint) -> CGFloat {
        let graphMovement = self

        //    log("\n borderHelperX CALLED \n ")

        // where the nodesMap origin was on screen at the start of the gesture;
        // takes into account graph offset.
        //    let adjustedOriginAtStart = startOrigins.x +

        // where eastern edge of blue nodes box was at when gesture started
        let easternNodeAtStart = startOrigins.x + graphBounds.size.width.magnitude/2 + graphMovement.localPreviousPosition.x

        // where eastern edge of blue nodes box is currently at
        let easternNode = graphBounds.origin.x + graphBounds.size.width.magnitude/2 + graphMovement.localPosition.x

        // where western edge of blue nodes box was at when gesture started
        let westernNodeAtStart = startOrigins.x - graphBounds.size.width.magnitude/2 + graphMovement.localPreviousPosition.x

        // where western edge of blue nodes box is currently at
        let westernNode = graphBounds.origin.x - graphBounds.size.width.magnitude/2 + graphMovement.localPosition.x

        // what we test eastern-most node against
        let westernBorder: CGFloat = 0

        // what we test western-most node against
        let easternBorder: CGFloat = frame.width

        //    log("borderHelperX westernBorder: \(westernBorder)")
        //    log("borderHelperX easternBorder: \(easternBorder)")
        //    log("borderHelperX gestureTranslation: \(gestureTranslation)")
        //    log("borderHelperX: easternNodeAtStart: \(easternNodeAtStart)")
        //    log("borderHelperX: easternNode: \(easternNode)")
        //    log("borderHelperX: westernNodeAtStart: \(westernNodeAtStart)")
        //    log("borderHelperX: westernNode: \(westernNode)")

        // false when we have never yet been at/over the border;
        // true in all other cases of this gesture
        let hasExistingMaxTranslationX: Bool = graphMovement.maxTranslationX.isDefined

        // 0 = the western edge of the device screen;
        // if eastern bound of blue box is equal to or smaller than that,
        // then we've hit the western border.
        let eastNodeNotYetAtWestBorder = easternNode >= westernBorder
        let westNodeNotYetAtEastBorder = westernNode <= easternBorder

        //    log("borderHelperX: eastNodeNotYetAtWestBorder: \(eastNodeNotYetAtWestBorder)")
        //    log("borderHelperX: westNodeNotYetAtEastBorder: \(westNodeNotYetAtEastBorder)")

        // Since we never move past the border,
        // it's really the `!hasExistingMaxTranslationX` which does all the work here.
        if eastNodeNotYetAtWestBorder && westNodeNotYetAtEastBorder,
           !hasExistingMaxTranslationX {
            //        log("borderHelperX: still have distance to travel and have never yet hit the border.")

            // set false
            graphMovement.currentlyOffsidesWest = false
            graphMovement.currentlyOffsidesEast = false

            return gestureTranslation.width
        }

        let eastNodeStartedPastWestBorder = easternNodeAtStart < westernBorder
        let westnodeStartedPastEastBorder = westernNodeAtStart > easternBorder

        //    log("borderHelperX: eastNodeStartedPastWestBorder: \(eastNodeStartedPastWestBorder)")

        // If we started past the border...
        if eastNodeStartedPastWestBorder,
           graphMovement.currentlyOffsidesWest.isDefined {
            //        log("borderHelperX: started offsides (west) and have not yet initialized variable")
            graphMovement.currentlyOffsidesWest = true
        }

        if westnodeStartedPastEastBorder,
           graphMovement.currentlyOffsidesEast.isDefined {
            //        log("borderHelperX: started offsides (east) and have not yet initialized variable")
            graphMovement.currentlyOffsidesEast = true
        }

        if let offsides = graphMovement.currentlyOffsidesWest,
           offsides {
            //        log("borderHelperX: still offsides (west); doing nothing special")
            return gestureTranslation.width
        }

        if let offsides = graphMovement.currentlyOffsidesEast,
           offsides {
            //        log("borderHelperX: still offsides (east); doing nothing special")
            return gestureTranslation.width
        }

        let maxWestwardTranslation = -(easternNodeAtStart.magnitude)

        // alternative: used if east node started west of the western border;
        let alternativeMaxWestwardTranslation = easternNodeAtStart.magnitude

        // how far we can move the graph before the western node hits the eastern border
        let maxEastwardTranslation = abs(easternBorder - westernNodeAtStart)

        // If west node started offsides (eastern border),
        let alternativeMaxEastwardTranslation = -1 * (westernNodeAtStart - easternBorder).magnitude

        //    log("borderHelperX: maxWestwardTranslation: \(maxWestwardTranslation)")
        //    log("borderHelperX: alternativeMaxWestwardTranslation: \(alternativeMaxWestwardTranslation)")
        //    log("borderHelperX: maxEastwardTranslation: \(maxEastwardTranslation)")
        //    log("borderHelperX: alternativeMaxEastwardTranslation: \(alternativeMaxEastwardTranslation)")

        // ie "Are we translating the eastern node toward the western border? (whether translation is negative or positive)"

        // Initialized in simple manner: "we're moving toward
        var translatingTowardWest: Bool = gestureTranslation.width < 0

        if eastNodeStartedPastWestBorder {
            translatingTowardWest = true
        }

        if westnodeStartedPastEastBorder {
            translatingTowardWest = false
        }

        //    log("borderHelperX: translatingTowardWest: \(translatingTowardWest)")

        // Initializing the max translation in the x direction
        if !hasExistingMaxTranslationX {
            //        log("\n borderHelperX: first time at/over the border")

            // If translation is moving west (ie negative), use maxWesterdTranslation.
            // DOES NOT NEED TO BE SCALED.
            // TODO: will cause problems if exactly 0 ? But then gesture handler wouldn't even fire?
            var maxTranslationX = translatingTowardWest ? maxWestwardTranslation : maxEastwardTranslation

            //        log("borderHelperX: first time: initial maxTranslationX: \(maxTranslationX)")

            if eastNodeStartedPastWestBorder {
                maxTranslationX = alternativeMaxWestwardTranslation
                //            log("borderHelperX: first time: eastNodeStartedPastWestBorder: final maxTranslationX: \(maxTranslationX)")
            }
            if westnodeStartedPastEastBorder {
                maxTranslationX = alternativeMaxEastwardTranslation
                //            log("borderHelperX: first time: westnodeStartedPastEastBorder: final maxTranslationX: \(maxTranslationX)")
            }

            // ^^ translationTowardWest = gestureTranslation.width is negative
            // but that's only when we started from the east and have been moving west toward the western border
            // ... not valid when we started west (ie offsides) and have been moving east toward the border
            // and then also, the max translation is messed up, since

            //        log("borderHelperX: first time: state.frame.size: \(state.frame.size)")
            //        log("borderHelperX: first time: graphBounds: \(graphBounds)")
            //        log("borderHelperX: first time: maxWestwardTranslation: \(maxWestwardTranslation)")
            //        log("borderHelperX: first time: maxEastwardTranslation: \(maxEastwardTranslation)")
            //        log("borderHelperX: first time: maxTranslationX: \(maxTranslationX)")

            graphMovement.maxTranslationX = maxTranslationX
        }

        // From here on out, we assume that we have a maxTranslation from
        guard let maxTranslationX: CGFloat = graphMovement.maxTranslationX else {
            fatalError("Should have had maxTranslation by this point")
        }

        //    log("borderHelperX: maxTranslationX: \(maxTranslationX)")

        // From this point on:
        // - any further gestureTranslations to the west are ignored, except to be saved as history so that we can know when we're moving

        // If we had a last invalid translation,
        // and our current translation is farther east of that,
        // then add the eastward-diff to the maxTranslation
        // (ie we've starting moving east again).
        if let lastInvalidTranslationX = graphMovement.lastInvalidTranslationX,
           maxTranslationX == maxWestwardTranslation
            || maxTranslationX == alternativeMaxWestwardTranslation,
           // ie Started moving east compared to last translation:
           gestureTranslation.width > lastInvalidTranslationX {

            let diff = abs(lastInvalidTranslationX - gestureTranslation.width)
            //        log("Had lastInvalidTranslationX: \(lastInvalidTranslationX)")
            //        log("Had lastInvalidTranslationX: started moving east: diff: \(diff)")

            return maxTranslationX + diff // + because eastward
        }

        // If we had a last invalid translation,
        // and our current translation is farther west of that,
        // then add the westward-diff to the maxTranslation.
        else if let lastInvalidTranslationX = graphMovement.lastInvalidTranslationX,
                maxTranslationX == maxEastwardTranslation ||
                    maxTranslationX == alternativeMaxEastwardTranslation,
                // ie Started moving west compared to last translation:
                gestureTranslation.width < lastInvalidTranslationX {

            let diff = abs(lastInvalidTranslationX - gestureTranslation.width)

            //        log("Had lastInvalidTranslationX: \(lastInvalidTranslationX)")
            //        log("Had lastInvalidTranslationX: started moving west: diff: \(diff)")
            return maxTranslationX - diff // - because westward

        }

        // else, just use maxTranslation for actual graph calc,
        // and set current translation as lastInvalidTranslation for later
        else {
            //        log("Did not have lastInvalidTranslation and/or was not moving east; will use un-modified maxTranslation: \(maxTranslationX)")
            graphMovement.lastInvalidTranslationX = gestureTranslation.width

            return maxTranslationX
        }
    }

    // called when a graph drag handler fires;
    // returns (actualTranslationForThisDimension,
    //          updatedGraphUIState)
    @MainActor
    func borderHelperY(gestureTranslation: CGSize,
                       easternMostNodeX: CGFloat,
                       //                   state: GraphUIState,
                       frame: CGRect,
                       graphBounds: CGRect,
                       startOrigins: CGPoint) -> CGFloat {
        let graphMovement = self

        //    log("\n borderHelperY CALLED \n ")
        //    var state = state

        // where the nodesMap origin was on screen at the start of the gesture;
        // takes into account graph offset.
        //    let adjustedOriginAtStart = startOrigins.x +

        // where eastern edge of blue nodes box was at when gesture started
        let southernNodeAtStart = startOrigins.y + graphBounds.size.height.magnitude/2 + graphMovement.localPreviousPosition.y

        // where eastern edge of blue nodes box is currently at
        let southernNode = graphBounds.origin.y + graphBounds.size.height.magnitude/2 + graphMovement.localPosition.y

        // where western edge of blue nodes box was at when gesture started
        let northernNodeAtStart = startOrigins.y - graphBounds.size.height.magnitude/2 + graphMovement.localPreviousPosition.y

        // where western edge of blue nodes box is currently at
        let northernNode = graphBounds.origin.y - graphBounds.size.height.magnitude/2 + graphMovement.localPosition.y

        // what we test eastern-most node against
        let northernBorder: CGFloat = 0

        // what we test western-most node against
        let southernBorder: CGFloat = frame.height

        // false when we have never yet been at/over the border;
        // true in all other cases of this gesture
        let hasExistingMaxTranslationY: Bool = graphMovement.maxTranslationY.isDefined

        // translatingNorth
        //    let translatingTowardNorth: Bool = gestureTranslation.height < 0

        // 0 = the western edge of the device screen;
        // if eastern bound of blue box is equal to or smaller than that,
        // then we've hit the western border.
        let southNodeNotYetAtNorthernBorder = southernNode >= northernBorder
        let northNodeNotYetAtSouthernBorder = northernNode <= southernBorder

        // Since we never move past the border,
        // it's really the `!hasExistingMaxTranslationX` which does all the work here.
        if southNodeNotYetAtNorthernBorder && northNodeNotYetAtSouthernBorder,
           !hasExistingMaxTranslationY {
            //        log("borderHelperY: still have distance to travel and have never yet hit the border.")

            graphMovement.currentlyOffsidesNorth = false
            graphMovement.currentlyOffsidesSouth = false

            return gestureTranslation.height
        }

        // At the start of this gesture,
        // was the southern-most node ABOVE the northern border (= 0) ?
        let southNodeStartedPastNorthBorder = southernNodeAtStart < northernBorder
        let northNodeStartedPastSouthBorder = northernNodeAtStart > southernBorder

        // If we started past the border...
        if southNodeStartedPastNorthBorder
            && !graphMovement.currentlyOffsidesNorth.isDefined {
            //        log("borderHelperY: started offsides (north) and have not yet initialized variable")
            graphMovement.currentlyOffsidesNorth = true
        }

        if northNodeStartedPastSouthBorder
            && !graphMovement.currentlyOffsidesSouth.isDefined {
            //        log("borderHelperY: started offsides (south) and have not yet initialized variable")
            graphMovement.currentlyOffsidesSouth = true
        }

        if let offsides = graphMovement.currentlyOffsidesNorth,
           offsides {
            //        log("borderHelperY: still offsides (north); doing nothing special")
            return gestureTranslation.height
        }

        if let offsides = graphMovement.currentlyOffsidesSouth,
           offsides {
            //        log("borderHelperY: still offsides (south); doing nothing special")
            return gestureTranslation.height
        }

        // how far we can move the graph before the eastern node hits the western border
        // - because moving west;
        let maxNorthwardTranslation = -(southernNodeAtStart.magnitude)
        let alternativeMaxNorthwardTranslation = southernNodeAtStart.magnitude

        // how far we can move the graph before the western node hits the eastern border
        let maxSouthwardTranslation = abs(southernBorder - northernNodeAtStart)
        let alternativeMaxSouthwardTranslation = -1 * (northernNodeAtStart - southernBorder).magnitude

        var translatingTowardNorth = gestureTranslation.height < 0

        if southNodeStartedPastNorthBorder {
            translatingTowardNorth = true
        }

        if northNodeStartedPastSouthBorder {
            translatingTowardNorth = false
        }

        // Initializing the max translation in the x direction
        if !hasExistingMaxTranslationY {
            //        log("\n borderHelperY: first time at/over the border")

            // If translation is moving west (ie negative), use maxWesterdTranslation.
            // DOES NOT NEED TO BE SCALED.
            var maxTranslationY = translatingTowardNorth ? maxNorthwardTranslation : maxSouthwardTranslation

            if southNodeStartedPastNorthBorder {
                maxTranslationY = alternativeMaxNorthwardTranslation
            }
            if northNodeStartedPastSouthBorder {
                maxTranslationY = alternativeMaxSouthwardTranslation
            }

            graphMovement.maxTranslationY = maxTranslationY
        }

        // From here on out, we assume that we have a maxTranslation from
        guard let maxTranslationY: CGFloat = graphMovement.maxTranslationY else {
            fatalError("Should have had maxTranslation by this point")
        }

        //    log("borderHelperY: first time: maxTranslationY: \(maxTranslationY)")

        //    let lastInvalidTranslationY = state.graphMovement.lastInvalidTranslationY

        // From this point on:
        // - any further gestureTranslations to the west are ignored, except to be saved as history so that we can know when we're moving

        // If we had a last invalid translation,
        // and our current translation is farther east of that,
        // then add the eastward-diff to the maxTranslation
        // (ie we've starting moving east again).
        if let lastInvalidTranslationY = graphMovement.lastInvalidTranslationY,
           maxTranslationY == maxNorthwardTranslation
            || maxTranslationY == alternativeMaxNorthwardTranslation,
           // ie Started moving south compared to last translation:
           gestureTranslation.height > lastInvalidTranslationY {

            let diff = abs(lastInvalidTranslationY - gestureTranslation.height)
            //        log("Had lastInvalidTranslationY: \(lastInvalidTranslationY)")
            //        log("Had lastInvalidTranslationY: started moving south: diff: \(diff)")

            return maxTranslationY + diff // + because eastward
        }

        // If we had a last invalid translation,
        // and our current translation is farther west of that,
        // then add the westward-diff to the maxTranslation.
        else if let lastInvalidTranslationY = graphMovement.lastInvalidTranslationY,
                maxTranslationY == maxSouthwardTranslation
                    || maxTranslationY == alternativeMaxSouthwardTranslation,
                // ie Started moving north compared to last translation:
                gestureTranslation.height < lastInvalidTranslationY {

            let diff = abs(lastInvalidTranslationY - gestureTranslation.height)

            //        log("Had lastInvalidTranslationY: \(lastInvalidTranslationY)")
            //        log("Had lastInvalidTranslationY: started moving north: diff: \(diff)")
            return maxTranslationY - diff // - because westward
        }

        // else, just use maxTranslation for actual graph calc,
        // and set current translation as lastInvalidTranslation for later
        else {
            //        log("Did not have lastInvalidTranslation and/or was not moving north or south; will use un-modified maxTranslation: \(maxTranslationY)")
            graphMovement.lastInvalidTranslationY = gestureTranslation.height

            return maxTranslationY
        }
    }
}

extension GraphState {
    @MainActor
    func handleGraphDraggedDuringSelection(_ gestureLocation: CGPoint) {
        guard let gestureStartLocation = self.graphUI.selection.dragStartLocation else {
            log("GraphState.handleGraphDraggedDuringSelection: no start location")
            return

        }
        var box = self.graphUI.selection.expansionBox

        if box.size == .zero {
            box.startPoint = gestureStartLocation
        }

        // CHANGE THE BOX BUT DO NOT CHANGE THE SELECTED NODES;
        // instead, node-selection is handled via SwiftUI preference values.
        let (newSize, newDirection) = trigCalc(
            start: gestureStartLocation,
            end: gestureLocation)

        box.size = newSize
        box.expansionDirection = newDirection
        box.endPoint = gestureLocation

        self.graphUI.selection.expansionBox = box
    }

    @MainActor
    func handleGraphScrolled(_ translation: CGSize,
                             wasTrackpadScroll: Bool) {

        // Scrolling the graph immediately exits edge-editing state and disables edge-animation
        // setOnChange needed to prevent extra render cycles
        if self.graphUI.edgeEditingState != nil {
            self.graphUI.edgeEditingState = nil
        }

        if self.graphUI.edgeAnimationEnabled {
            self.graphUI.edgeAnimationEnabled = false
        }

        // End dragging if some event (i.e. graph tap) happened
        guard self.graphUI.selection.graphDragState == .dragging else {
            log("handleGraphScrolled: ended due to cancelled dragging from other event.")
            self.graphDragEnded(location: nil,
                                velocity: .zero,
                                wasScreenDrag: false)
            return
        }

        // Dragging on the graph restarts the momentum.
        // NOTE: we must do this before updating the position,
        // in order to make sure that the updatePosition call
        // has a previousPosition that reflects the momentum movement.
        if self.graphMovement.shouldRun {
            self.graphMovement.resetGraphMovement()
        }

        //    log("handleGraphScrolled: state.graphUI.graphMovement.localPosition was: \(state.graphUI.graphMovement.localPosition)")

        //    log("handleGraphScrolled: translation was: \(translation)")

        // Always update the graph offset,
        // regardless whether there is another active gesture.
        self.graphMovement.localPosition = self.localPreviousPosition + (translation.toCGPoint / self.graphMovement.zoomData.zoom)

        //    log("handleGraphScrolled: state.graphUI.graphMovement.localPosition is now: \(state.graphUI.graphMovement.localPosition)")

        self.graphMovement.runningGraphTranslation = translation

        // DUAL DRAG:

        self.graphMovement.graphIsDragged = true

        // If we don't have an active first gesture,
        // and node isn't already dragging,
        // then set graph-drag as active first gesture
        if self.graphMovement.firstActive == .none {
            if !self.graphMovement.canvasItemIsDragged {
                log("graphDrag onChanged: will set .graph as active first gesture")
                self.graphMovement.firstActive = .graph
            }
        }

        self.graphMovement.runningGraphTranslation = translation

        // If we're simultaneously dragging the node,
        // add inverse graph translation to node's position,
        // so that node stays under our finger:
        if self.graphMovement.canvasItemIsDragged {

            self.selectedCanvasItems.forEach { node in
            // self.getSelectedNodeViewModels().forEach { node in
                node.updateNodeOnGraphDragged(
                    translation,
                    self.highestZIndex + 1,
                    zoom: self.graphMovement.zoomData.zoom,
                    state: self.graphMovement)
            }

            //    log("handleGraphScrolled: state.graphMovement.localPosition is now: \(state.graphMovement.localPosition)")
        }

        self.graphMovement.wasTrackpadScroll = wasTrackpadScroll
    }

    // `handleGraphScrolled` is kept relatively pure and separate;
    // but in many drag cases we need to do border checks (graph min/max),
    // so here we do that prep-work:

    // nil = no prep work to be done; ie we didn't hit any borders yet
    @MainActor
    func handleGraphScrollWithBorders(gestureTranslation: CGSize,
                                      wasTrackpadScroll: Bool) {

        // SEE GITHUB ISSUE ABOUT OPTIMIZING BORDER-CHECKING FOR LARGE GRAPHS:
        // https://github.com/vpl-codesign/stitch/issues/2469
        self.handleGraphScrolled(
            gestureTranslation,
            wasTrackpadScroll: wasTrackpadScroll)
    }
}

extension GraphMovementObserver {
    @MainActor
    func resetGraphOffsetBorderDataAfterDragEnded() {
        self.maxTranslationX = nil
        self.maxTranslationY = nil

        self.lastInvalidTranslationX = nil
        self.lastInvalidTranslationY = nil

        self.graphBoundOriginAtStart = nil

        self.currentlyOffsidesWest = nil
        self.currentlyOffsidesEast = nil
        self.currentlyOffsidesNorth = nil
        self.currentlyOffsidesSouth = nil
    }
}

extension GraphState {
    @MainActor
    func handleTrackpadGraphDragEnded() {

        //    log("handleTrackpadGraphDragEnded called")

        let state = self.graphUI
        let graphMovement = self.graphMovement

        // DO NOT reset selected nodes themselves
        state.selection.expansionBox = ExpansionBox()
        state.selection.isSelecting = false
        state.selection.dragStartLocation = nil
        state.selection.dragCurrentLocation = nil

        // always reset 'wasTrackpadScroll'
        graphMovement.wasTrackpadScroll = false

        graphMovement.draggedCanvasItem = nil
    }

    // you should pass in GraphMovement
    @MainActor
    func graphDragEnded(location: CGPoint?,
                        velocity: CGPoint,
                        wasScreenDrag: Bool) {

        let graphMovement = self.graphMovement
        let graphUIState = self.graphUI

        let doNotStartMomentum = wasScreenDrag && graphUIState.selection.isSelecting

        // always set start and current location of drag gesture
        graphUIState.selection.dragStartLocation = nil

        if location.isDefined {
            graphUIState.selection.dragCurrentLocation = nil
        }

        graphUIState.selection.expansionBox = ExpansionBox()
        graphUIState.selection.isSelecting = false

        //    log("handleGraphDragEnded: state.graphMovement.localPreviousPosition was \(state.graphMovement.localPreviousPosition)")
        //    log("handleGraphDragEnded: state.graphMovement.localPosition was \(state.graphMovement.localPosition)")

        // NORMAL:

        graphMovement.localPreviousPosition = graphMovement.localPosition

        // DUAL DRAG:

        graphMovement.graphIsDragged = false

        // Only add to `accumulated` if we're indeed dragging at least one node
        if graphMovement.canvasItemIsDragged {
            graphMovement.accumulatedGraphTranslation += (graphMovement.runningGraphTranslation ?? .zero) / graphMovement.zoomData.zoom
        }

        graphMovement.runningGraphTranslation = nil

        if graphMovement.canvasItemIsDragged {
            //        log("graphDrag: onEnded: will set .graph as active first gesture")
            graphMovement.firstActive = .node
        } else {
            //        log("graphDrag: onEnded: will set .none as active first gesture")
            graphMovement.firstActive = .none
        }

        // BORDER:

        graphMovement.resetGraphOffsetBorderDataAfterDragEnded()

        // TODO: What happens if we zoom in or out *while momentum is running*?
        let momentumOrigin = self
            .graphBounds(graphMovement.zoomData.zoom,
                         graphView: graphUIState.frame,
                         graphOffset: graphMovement.localPosition,
                         groupNodeFocused: graphUIState.groupNodeFocused)

        //    log("handleGraphDragEnded: momentumOrigin: \(momentumOrigin)")

        // start momentum
        if !doNotStartMomentum {
            //        log("handleGraphDragEnded: will initialize momentum: momentumOrigin: \(momentumOrigin)")

            graphMovement
                .momentumState = startMomentum(graphMovement.momentumState,
                                               graphMovement.zoomData.zoom,
                                               velocity)

            // also set graphOrigins; JUST FOR GRAPH DRAG AND GRAPH MOMENTUM
            if let origin = momentumOrigin?.origin {
                graphMovement

                    .graphBoundOriginAtStart = .init(
                        origin: origin,
                        setByMomentum: true)
            }
        }

        // always reset 'wasTrackpadScroll'
        graphMovement.wasTrackpadScroll = false

        // Wipe comment box bounds
        graphUIState.wipeCommentBoxBounds()

        // Cancel any possible active graph pan gesture
        graphUIState.selection.graphDragState = .none
    }
}

extension GraphState {
    @MainActor
    func wipeCommentBoxBounds() {
        self.graphUI.wipeCommentBoxBounds()
    }
}

extension GraphUIState {
    @MainActor
    func wipeCommentBoxBounds() {
        self.commentBoxBoundsDict = .init()
    }
}

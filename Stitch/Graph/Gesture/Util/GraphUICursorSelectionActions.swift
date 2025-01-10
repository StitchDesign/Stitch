//
//  GraphUICursorSelectionActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/17/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Actions and helpers related to the nodes-selection box
// (ie what shows up when we long press on the graph or click+drag graph via trackpad)

struct GraphBackgroundLongPressed: StitchDocumentEvent {
    let location: CGPoint
    
    @MainActor // All actions already happen on main thread?
    func handle(state: StitchDocumentViewModel) {
        log("GraphBackgroundLongPressed called")
        state.graphUI.selection.isSelecting = true
        state.graphUI.selection.dragStartLocation = location
        state.graphUI.selection.dragCurrentLocation = location
        state.graphUI.selection.isFingerOnScreenSelection = true
//        state.graphUI.selection.expansionBox = .init(origin: location, size: .zero)
        state.graphUI.selection.expansionBox = .init()
        state.graphUI.selection.expansionBox?.startPoint = location
        state.graphUI.selection.graphDragState = .none
    }
}

struct GraphBackgroundLongPressEnded: StitchDocumentEvent {
    
    @MainActor
    func handle(state: StitchDocumentViewModel) {
        log("GraphBackgroundLongPressEnded called")
        state.graphUI.selection.dragStartLocation = nil
        state.graphUI.selection.dragCurrentLocation = nil
        state.graphUI.selection.expansionBox = nil
        state.graphUI.selection.isSelecting = false
        state.graphMovement.localPreviousPosition = state.graphMovement.localPosition
    }
}

struct GraphBackgroundTrackpadDragged: StitchDocumentEvent {
    
    let translation: CGSize
    let location: CGPoint
    let velocity: CGPoint
    let numberOfTouches: Int
    let gestureState: UIGestureRecognizer.State
    let shiftHeld: Bool
    
    func handle(state: StitchDocumentViewModel) {
        
        if state.keypressState.isSpacePressed || state.graphUI.activeSpacebarClickDrag {
            log("GraphBackgroundTrackpadDragged: space held, or have active spacebar drag, so will exit early")
            
            return
        } else {
            state.trackpadDragWhileSpaceNotHeld(
                translation: translation,
                location: location,
                velocity: velocity,
                numberOfTouches: numberOfTouches,
                gestureState: gestureState,
                shiftHeld: shiftHeld)
        }
    }
}


extension StitchDocumentViewModel {

    
    @MainActor
    func trackpadDragWhileSpaceNotHeld(translation: CGSize,
                                       location: CGPoint,
                                       velocity: CGPoint,
                                       numberOfTouches: Int,
                                       gestureState: UIGestureRecognizer.State,
                                       shiftHeld: Bool) {
        self.graphUI.activeSpacebarClickDrag = false

        self.clickDragAsNodeSelection(translation: translation,
                                      location: location,
                                      gestureState: gestureState,
                                      numberOfTouches: numberOfTouches,
                                      shiftHeld: shiftHeld)
    }
    
    @MainActor
    func trackpadClickDrag(translation: CGSize,
                           location: CGPoint,
                           velocity: CGPoint,
                           numberOfTouches: Int,
                           gestureState: UIGestureRecognizer.State,
                           shiftHeld: Bool) {
        //        log("TrackpadClickDragEvent")

        let spaceHeld = self.keypressState.isSpacePressed
        let activeSpacebarDrag = self.graphUI.activeSpacebarClickDrag

        // log("TrackpadClickDragEvent: spaceHeld: \(spaceHeld)")
        // log("TrackpadClickDragEvent: activeSpacebarDrag: \(activeSpacebarDrag)")

        // Cancel all graph drag if non-mouse scroll--fixes graph jumping issue caused by graph selection
        // processing after graph scroll due to race condition
        if numberOfTouches == 1 && !spaceHeld {
            self.graphUI.selection.graphDragState = .none
        }

        // treat click+drag as graph pan

        // If we were in the middle of an active Spacebar click+drag,
        // but we let go of the space key,
        // then we need to immediately do a `graph drag ended`
        if !spaceHeld && activeSpacebarDrag {
            //            state.graphUI = handleGraphDragEnded(
            self.graphDragEnded(
                location: location,
                velocity: velocity,
                wasScreenDrag: true)
            self.graphUI.activeSpacebarClickDrag = false
        }

        //
        if spaceHeld {

            // Start an active graph gesture
            self.graphUI.selection.graphDragState = .dragging
            self.graphUI.activeSpacebarClickDrag = true

            switch gestureState {

            case .changed:
                // Should only have a single touch
                if numberOfTouches == 1 {
                    self.graphDragged(translation: translation,
                                      location: location)
                    return
                }
                return

            case .ended, .cancelled:
                // should have no touches
                if numberOfTouches == 0 {
                    self.graphUI.activeSpacebarClickDrag = false

                    self.graphDragEnded(location: location,
                                        velocity: velocity,
                                        wasScreenDrag: true)
                } else {
                    self.graphUI.activeSpacebarClickDrag = false
                }
                return

            default:
                return
            }
        }

        // treat click+drag as node selection box
        else {
            self.graphUI.activeSpacebarClickDrag = false

            self.clickDragAsNodeSelection(translation: translation,
                                          location: location,
                                          gestureState: gestureState,
                                          numberOfTouches: numberOfTouches,
                                          shiftHeld: shiftHeld)
            return
        }
    }

    @MainActor
    func clickDragAsNodeSelection(translation: CGSize,
                                  location: CGPoint,
                                  gestureState: UIGestureRecognizer.State,
                                  numberOfTouches: Int,
                                  shiftHeld: Bool) {
        switch gestureState {
        case .began:
            // log("clickDragAsNodeSelection: began: location: \(location)")
            //        return handleTrackpadDragStarted(
            if numberOfTouches == 1 {
                self.handleTrackpadDragStarted(
                    location: location)
            }

        case .changed:
            // log("clickDragAsNodeSelection: changed: location: \(location)")
            //        return handleTrackpadGraphDragChanged(
            if numberOfTouches == 1 {
                self.handleTrackpadGraphDragChanged(
                    gestureTranslation: translation,
                    gestureLocation: location,
                    shiftHeld: shiftHeld)
            }

        case .ended, .cancelled:
            self.handleTrackpadGraphDragEnded()

        default:
            return
        }
    }

    @MainActor
    func handleTrackpadDragStarted(location: CGPoint) {
        
        // log("handleTrackpadDragStarted: self.graphUI.selection.isFingerOnScreenSelection was: \(self.graphUI.selection.isFingerOnScreenSelection)")
        
        self.graphUI.selection.dragStartLocation = location
        self.graphUI.selection.dragCurrentLocation = location
        self.graphUI.selection.isFingerOnScreenSelection = false
//        self.graphUI.selection.expansionBox = .init(origin: location, size: .zero)
        self.graphUI.selection.expansionBox = .init()
        self.graphUI.selection.expansionBox?.startPoint = location
        self.graphUI.selection.isSelecting = true
        self.graphUI.selection.graphDragState = .none

        self.visibleGraph.selectedEdges = .init()
        
        // log("handleTrackpadDragStarted: self.graphUI.selection.isFingerOnScreenSelection is now: \(self.graphUI.selection.isFingerOnScreenSelection)")
    }

    @MainActor
    func handleTrackpadGraphDragChanged(gestureTranslation: CGSize,
                                        gestureLocation: CGPoint,
                                        shiftHeld: Bool) {
        if !self.graphUI.selection.isSelecting {
            log("handleTrackpadGraphDragChanged: TrackpadGraphDragChangedAction called but we weren't selecting...")
        }

        if shiftHeld {
            // log("handleTrackpadGraphDragChanged: had shift")
            //            self.keypressState.modifiers.insert(.shift)
            self.keypressState.shiftHeldDuringGesture = true
        } else {
            // log("handleTrackpadGraphDragChanged: did not have shift")
            //            self.keypressState.modifiers.remove(.shift)
            self.keypressState.shiftHeldDuringGesture = false
        }
        
        self.graphUI.selection.isSelecting = true
        self.graphUI.selection.dragCurrentLocation = gestureLocation
        self.handleGraphDraggedDuringSelection(gestureLocation)
    }
}

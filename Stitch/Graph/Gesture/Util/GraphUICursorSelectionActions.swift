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

extension StitchDocumentViewModel {
    @MainActor
    func screenLongPressed(location: CGPoint) {
        self.graphUI.selection.isSelecting = true
        self.graphUI.selection.dragStartLocation = location
        self.graphUI.selection.dragCurrentLocation = location
        self.graphUI.selection.isFingerOnScreenSelection = true
        self.graphUI.selection.expansionBox.startPoint = location
        self.graphUI.selection.graphDragState = .none
    }

    @MainActor
    func screenLongPressEnded() {
        self.graphUI.selection.dragStartLocation = nil
        self.graphUI.selection.dragCurrentLocation = nil
        self.graphUI.selection.expansionBox = ExpansionBox()
        self.graphUI.selection.isSelecting = false
        self.graphMovement.localPreviousPosition = self.graphMovement.localPosition
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
            //        return handleTrackpadDragStarted(
            if numberOfTouches == 1 {
                self.handleTrackpadDragStarted(
                    location: location)
            }

        case .changed:
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
        let graphUI = self.graphUI
        graphUI.selection.dragStartLocation = location
        graphUI.selection.dragCurrentLocation = location
        graphUI.selection.isFingerOnScreenSelection = false
        graphUI.selection.expansionBox.startPoint = location
        graphUI.selection.isSelecting = true
        graphUI.selection.graphDragState = .none

        self.visibleGraph.selectedEdges = .init()
    }

    @MainActor
    func handleTrackpadGraphDragChanged(gestureTranslation: CGSize,
                                        gestureLocation: CGPoint,
                                        shiftHeld: Bool) {
        if !self.graphUI.selection.isSelecting {
            log("handleTrackpadGraphDragChanged: TrackpadGraphDragChangedAction called but we weren't selecting...")
        }

        if shiftHeld {
            log("handleTrackpadGraphDragChanged: had shift")
//            self.keypressState.modifiers.insert(.shift)
            self.keypressState.shiftHeldDuringGesture = true
        } else {
            log("handleTrackpadGraphDragChanged: did not have shift")
//            self.keypressState.modifiers.remove(.shift)
            self.keypressState.shiftHeldDuringGesture = false
        }
        
        self.graphUI.selection.isSelecting = true
        self.graphUI.selection.dragCurrentLocation = gestureLocation
        self.handleGraphDraggedDuringSelection(gestureLocation)
    }
}

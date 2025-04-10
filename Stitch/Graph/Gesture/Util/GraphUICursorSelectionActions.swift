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

struct GraphBackgroundLongPressed: GraphEvent {
    let location: CGPoint
    
    @MainActor // All actions already happen on main thread?
    func handle(state: GraphState) {
        log("GraphBackgroundLongPressed called")
        state.selection.isSelecting = true
        state.selection.dragStartLocation = location
        state.selection.dragCurrentLocation = location
        state.selection.isFingerOnScreenSelection = true
//        state.selection.expansionBox = .init(origin: location, size: .zero)
        state.selection.expansionBox = .init()
        state.selection.expansionBox?.startPoint = location
        state.selection.graphDragState = .none
    }
}

struct GraphBackgroundLongPressEnded: GraphEvent {
    
    @MainActor
    func handle(state: GraphState) {
        guard let graphMovement = state.documentDelegate?.graphMovement else {
            fatalErrorIfDebug()
            return
        }
        
        log("GraphBackgroundLongPressEnded called")
        state.selection.dragStartLocation = nil
        state.selection.dragCurrentLocation = nil
        state.selection.expansionBox = nil
        state.selection.isSelecting = false
        graphMovement.localPreviousPosition = graphMovement.localPosition
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
        
        if state.keypressState.isSpacePressed || state.activeSpacebarClickDrag {
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
        self.activeSpacebarClickDrag = false
        
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
        
        let graph = self.visibleGraph
        let spaceHeld = self.keypressState.isSpacePressed
        let activeSpacebarDrag = self.activeSpacebarClickDrag
        
        // log("TrackpadClickDragEvent: spaceHeld: \(spaceHeld)")
        // log("TrackpadClickDragEvent: activeSpacebarDrag: \(activeSpacebarDrag)")
        
        // Cancel all graph drag if non-mouse scroll--fixes graph jumping issue caused by graph selection
        // processing after graph scroll due to race condition
        if numberOfTouches == 1 && !spaceHeld {
            graph.selection.graphDragState = .none
        }
        
        // treat click+drag as graph pan
        
        // If we were in the middle of an active Spacebar click+drag,
        // but we let go of the space key,
        // then we need to immediately do a `graph drag ended`
        if !spaceHeld && activeSpacebarDrag {
            //            state = handleGraphDragEnded(
            graph.graphDragEnded(
                location: location,
                velocity: velocity,
                wasScreenDrag: true,
                frame: self.frame)
            self.activeSpacebarClickDrag = false
        }
        
        //
        if spaceHeld {
            
            // Start an active graph gesture
            graph.selection.graphDragState = .dragging
            self.activeSpacebarClickDrag = true
            
            switch gestureState {
                
            case .changed:
                // Should only have a single touch
                if numberOfTouches == 1 {
                    graph.graphDragged(translation: translation,
                                       location: location,
                                       document: self)
                    return
                }
                return
                
            case .ended, .cancelled:
                // should have no touches
                if numberOfTouches == 0 {
                    self.activeSpacebarClickDrag = false
                    
                    graph.graphDragEnded(location: location,
                                         velocity: velocity,
                                         wasScreenDrag: true,
                                         frame: self.frame)
                } else {
                    self.activeSpacebarClickDrag = false
                }
                return
                
            default:
                return
            }
        }
        
        // treat click+drag as node selection box
        else {
            self.activeSpacebarClickDrag = false
            
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
        let graph = self.visibleGraph
        
        switch gestureState {
        case .began:
            // log("clickDragAsNodeSelection: began: location: \(location)")
            //        return handleTrackpadDragStarted(
            if numberOfTouches == 1 {
                graph.handleTrackpadDragStarted(
                    location: location)
            }
            
        case .changed:
            // log("clickDragAsNodeSelection: changed: location: \(location)")
            //        return handleTrackpadGraphDragChanged(
            if numberOfTouches == 1 {
                graph.handleTrackpadGraphDragChanged(
                    gestureTranslation: translation,
                    gestureLocation: location,
                    shiftHeld: shiftHeld,
                    document: self)
            }
            
        case .ended, .cancelled:
            graph.handleTrackpadGraphDragEnded()
            
        default:
            return
        }
    }
}

extension GraphState {
    @MainActor
    func handleTrackpadDragStarted(location: CGPoint) {
        
        // log("handleTrackpadDragStarted: self.selection.isFingerOnScreenSelection was: \(self.selection.isFingerOnScreenSelection)")
        
        self.selection.dragStartLocation = location
        self.selection.dragCurrentLocation = location
        self.selection.isFingerOnScreenSelection = false
//        self.selection.expansionBox = .init(origin: location, size: .zero)
        self.selection.expansionBox = .init()
        self.selection.expansionBox?.startPoint = location
        self.selection.isSelecting = true
        self.selection.graphDragState = .none

        self.selectedEdges = .init()
        
        // log("handleTrackpadDragStarted: self.selection.isFingerOnScreenSelection is now: \(self.selection.isFingerOnScreenSelection)")
    }

    @MainActor
    func handleTrackpadGraphDragChanged(gestureTranslation: CGSize,
                                        gestureLocation: CGPoint,
                                        shiftHeld: Bool,
                                        document: StitchDocumentViewModel) {
        if !self.selection.isSelecting {
            log("handleTrackpadGraphDragChanged: TrackpadGraphDragChangedAction called but we weren't selecting...")
        }

        if shiftHeld {
            // log("handleTrackpadGraphDragChanged: had shift")
            //            self.keypressState.modifiers.insert(.shift)
            document.keypressState.shiftHeldDuringGesture = true
        } else {
            // log("handleTrackpadGraphDragChanged: did not have shift")
            //            self.keypressState.modifiers.remove(.shift)
            document.keypressState.shiftHeldDuringGesture = false
        }
        
        self.selection.isSelecting = true
        self.selection.dragCurrentLocation = gestureLocation
        self.handleGraphDraggedDuringSelection(gestureLocation)
    }
}

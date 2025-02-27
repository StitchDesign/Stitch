//
//  StitchUIScrollHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/18/24.
//

import SwiftUI
import UIKit

struct SetGraphScrollDataUponPageChange: GraphEvent {
    let newPageLocalPosition: CGPoint
    let newPageZoom: CGFloat
    
    func handle(state: GraphState) {
        //        log("SetGraphScrollDataUponPageChange: newPageLocalPosition: \(newPageLocalPosition)")
        //        log("SetGraphScrollDataUponPageChange: newPageZoom: \(newPageZoom)")
        state.graphUI.canvasPageOffsetChanged = newPageLocalPosition
        state.graphUI.canvasPageZoomScaleChanged = newPageZoom
        
        /*
         Set all nodes visible for the field updates, since when we enter the new traversal level
         our infiniteCanvasCache may not yet have entries for canvas items at this level.
         
         Then, do the actual determination of onscreen nodes.
         
         (Similar to how, when first loading a project, we set all nodes visible before we call updateVisibleNodes to actually determine on- vs offscreen nodes.)
         
         Resolves:
         - https://github.com/StitchDesign/Stitch--Old/issues/6787
         - https://github.com/StitchDesign/Stitch--Old/issues/6779
         
         */
        // TODO: doesn't actually fix the issue? The above-level nodes are still *sometimes* what we see when we first enter the lower-level
        state.visibleNodesViewModel.setAllNodesVisible()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak state] in
            state?.updateVisibleNodes()
        }
    }
}


// UIScrollView's zooming also updates contentOffset,
// so we prefer to update both localPosition and zoomData at same time.
struct GraphScrollDataUpdated: StitchDocumentEvent {
    let newOffset: CGPoint
    let newZoom: CGFloat
    var shouldPersist: Bool = false // true just when e.g. we stopped decelerating
    
    func handle(state: StitchDocumentViewModel) {
        log("GraphScrollDataUpdated: newOffset: \(newOffset)")
        log("GraphScrollDataUpdated: newZoom: \(newZoom)")
        state.graphMovement.localPosition = newOffset
        state.graphMovement.zoomData = newZoom
        
        if shouldPersist {
            log("GraphScrollDataUpdated: will persist")
            state.encodeProjectInBackground()
        }
    }
    
}

struct StitchLongPressGestureRecognizerRepresentable: UIGestureRecognizerRepresentable {
    
    func makeUIGestureRecognizer(context: Context) -> some UIGestureRecognizer {
        // log("StitchLongPressGestureRecognizerRepresentable: makeUIGestureRecognizer")
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.5 // half a second
        
        // if not restricted to screen, can be recognized via long-press too
        // maybe force disable that on Catalyst?
        recognizer.allowedTouchTypes = [SCREEN_TOUCH_ID]
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UIGestureRecognizerType,
                                         context: Context) {
        
        // log("StitchLongPressGestureRecognizerRepresentable: handleUIGestureRecognizerAction")
        
        switch recognizer.state {
            
        case .began:
            if let view = recognizer.view {
                let location = recognizer.location(in: view)
                // log("StitchLongPressGestureRecognizerRepresentable: handleUIGestureRecognizerAction: BEGAN: location: \(location)")
                // Use an action to avoid having to worry about `weak var` vs `let` with StitchDocumentViewModel ?
                dispatch(GraphBackgroundLongPressed(location: location))
            }
            
        case .changed:
            let location = recognizer.location(in: recognizer.view)
            // log("StitchLongPressGestureRecognizerRepresentable: handleUIGestureRecognizerAction: CHANGED: location: \(location)")
            dispatch(GraphDraggedDuringSelection(location: location))
            
        case .ended, .cancelled:
            // log("StitchLongPressGestureRecognizerRepresentable: handleUIGestureRecognizerAction: ENDED/CANCELLED")
            dispatch(GraphBackgroundLongPressEnded())
            
        default:
            break
        }
    }
}

struct StitchTrackpadGraphBackgroundPanGesture: UIGestureRecognizerRepresentable {
    
    typealias UIGestureRecognizerType = UIPanGestureRecognizer
    
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        
        // log("StitchTrackpadGraphBackgroundPanGesture: makeUIGestureRecognizer")
        
        let delegate = context.coordinator
        
        let trackpadPanGesture = UIPanGestureRecognizer(
            target: delegate,
            action: #selector(delegate.trackpadPanInView))
        
        // Only listen to click and drag from mouse
        trackpadPanGesture.allowedScrollTypesMask = [.discrete]
        // ignore screen; uses trackpad
        trackpadPanGesture.allowedTouchTypes = [TRACKPAD_TOUCH_ID]
        // 1 touch ensures a click and drag event
        trackpadPanGesture.minimumNumberOfTouches = 1
        trackpadPanGesture.maximumNumberOfTouches = 1
        trackpadPanGesture.delegate = delegate
        
        return trackpadPanGesture
    }
        
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: StitchTrackpadGraphBackgroundPanGesture
        
        var shiftHeld: Bool = false
        
        init(parent: StitchTrackpadGraphBackgroundPanGesture) {
            self.parent = parent
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // log("StitchTrackpadGraphBackgroundPanGesture: gestureRecognizer: shouldRecognizeSimultaneouslyWith")
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldReceive event: UIEvent) -> Bool {
            // log("StitchTrackpadGraphBackgroundPanGesture: gestureRecognizer: should receive event")
            if event.modifierFlags.contains(.shift) {
                // log("StitchTrackpadGraphBackgroundPanGesture: SHIFT DOWN")
                self.shiftHeld = true
            } else {
                // log("StitchTrackpadGraphBackgroundPanGesture: SHIFT NOT DOWN")
                self.shiftHeld = false
            }
            return true
        }
        
        @objc func trackpadPanInView(_ gestureRecognizer: UIPanGestureRecognizer) {
            // log("StitchTrackpadGraphBackgroundPanGesture: trackpadPanInView recognized")
            
            // log("StitchTrackpadGraphBackgroundPanGesture: handleUIGestureRecognizerAction")
            
            let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
            let location = gestureRecognizer.location(in: gestureRecognizer.view)
            let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)
            
            // log("StitchTrackpadGraphBackgroundPanGesture: handleUIGestureRecognizerAction: gestureRecognizer.state.description: \(gestureRecognizer.state.description)")
            
            // log("StitchTrackpadGraphBackgroundPanGesture: handleUIGestureRecognizerAction: location: \(location)")
            
            dispatch(GraphBackgroundTrackpadDragged(
                translation: translation.toCGSize,
                location: location,
                velocity: velocity,
                numberOfTouches: gestureRecognizer.numberOfTouches,
                gestureState: gestureRecognizer.state,
                shiftHeld: self.shiftHeld))
        }
    }
}

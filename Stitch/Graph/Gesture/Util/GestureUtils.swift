//
//  GestureUtils.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/9/22.
//

import SwiftUI
import UIKit

extension NodeSelectionGestureRecognizer {
    @MainActor
    func screenGraphBackgroundPan(_ gestureRecognizer: UIPanGestureRecognizer) {

        //    log("handleScreenGraphPanGesture called")

        guard let view = gestureRecognizer.view else {
            fatalError("handleScreenGraphPanGesture error: no view found in screenPanInView.")
        }

        let translation = gestureRecognizer.translation(in: view)
        let location = gestureRecognizer.location(in: view)
        let velocity = gestureRecognizer.velocity(in: view)

        switch gestureRecognizer.state {
        
        case .began:
            
            if graph?.graphUI.llmRecording.isRecording ?? false {
                log("Graph pan disabled during LLM Recording")
                return
            }
            self.graph?.graphScrollBegan()
            
        case .changed:
            
            if graph?.graphUI.llmRecording.isRecording ?? false {
                log("Graph pan disabled during LLM Recording")
                return
            }
            // Should only have a single touch
            if gestureRecognizer.numberOfTouches == 1 {
                self.graph?.graphDragged(
                    // not an accurate translation?
                    translation: translation.toCGSize,
                    location: location)
            }
        
        case .ended, .cancelled:
            
            if graph?.graphUI.llmRecording.isRecording ?? false {
                log("Graph pan disabled during LLM Recording")
                return
            }
            
            // USEFUL FOR DEBUGGING / DEV
            //        log("handleScreenGraphPanGesture: screenPanInView: translation: \(translation)")
            //        log("handleScreenGraphPanGesture: screenPanInView: velocity: \(velocity)")
            // should have no touches
            if gestureRecognizer.numberOfTouches == 0 {
                self.graph?.graphDragEnded(
                    location: location,
                    velocity: velocity,
                    wasScreenDrag: true)
            }
            
        default:
            break
        }
    }
}

extension GraphGestureDelegate {
    @MainActor
    func trackpadGraphBackgroundPan(_ gestureRecognizer: UIPanGestureRecognizer) {
       
        guard let view = gestureRecognizer.view else {
            fatalError("handleTrackpadGraphPanGesture error: no view found in trackpadPanInView.")
        }

        let translation = gestureRecognizer.translation(in: view)

        // Check if Command key is pressed
        if self.graph?.graphUI.keypressState.isCommandPressed == true {
            // Determine zoom direction based on the y-direction of the translation
            switch gestureRecognizer.state {
            case .changed:
                if translation.y > 0 {
                    // Scrolling up, zoom in
                    self.graph?.graphZoomedIn(rate: Self.zoomScrollRate)
                } else if translation.y < 0 {
                    // Scrolling down, zoom out
                    self.graph?.graphZoomedOut(rate: Self.zoomScrollRate)
                }
            default:
                break
            }
        } else {
            // Handle regular scroll without zooming
            if gestureRecognizer.numberOfTouches == 0 {
                switch gestureRecognizer.state {
                case .began:
                    if graph?.graphUI.llmRecording.isRecording ?? false {
                        log("Graph pan disabled during LLM Recording")
                        return
                    }
                    self.graph?.graphScrollBegan()
                case .changed:
                    if graph?.graphUI.llmRecording.isRecording ?? false {
                        log("Graph pan disabled during LLM Recording")
                        return
                    }
                    self.graph?.graphScrolled(translation: translation)
                case .ended, .cancelled:
                    if graph?.graphUI.llmRecording.isRecording ?? false {
                        log("Graph pan disabled during LLM Recording")
                        return
                    }
                    self.graph?.graphDragEnded(
                        location: nil,
                        // `nil` vs `view` doesn't make a difference?
                        // velocity: gestureRecognizer.velocity(in: view),
                        velocity: gestureRecognizer.velocity(in: nil),
                        wasScreenDrag: false)
                default:
                    break
                }
            }
        }
    }
}

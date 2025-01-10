//
//  GestureUtils.swift
//  Stitch
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
            
//            if document?.llmRecording.isRecording ?? false {
//                log("Graph pan disabled during LLM Recording")
//                return
//            }
            self.document?.graphScrollBegan()
            
        case .changed:
            
//            if document?.llmRecording.isRecording ?? false {
//                log("Graph pan disabled during LLM Recording")
//                return
//            }
            // Should only have a single touch
            if gestureRecognizer.numberOfTouches == 1 {
                self.document?.graphDragged(
                    // not an accurate translation?
                    translation: translation.toCGSize,
                    location: location)
            }
        
        case .ended, .cancelled:
            
//            if document?.llmRecording.isRecording ?? false {
//                log("Graph pan disabled during LLM Recording")
//                return
//            }
            
            // USEFUL FOR DEBUGGING / DEV
            //        log("handleScreenGraphPanGesture: screenPanInView: translation: \(translation)")
            //        log("handleScreenGraphPanGesture: screenPanInView: velocity: \(velocity)")
            // should have no touches
            if gestureRecognizer.numberOfTouches == 0 {
                self.document?.graphDragEnded(
                    location: location,
                    velocity: velocity,
                    wasScreenDrag: true)
            }
            
        default:
            break
        }
    }
}

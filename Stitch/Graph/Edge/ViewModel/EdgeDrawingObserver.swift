//
//  PortDragState.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/19/22.
//

import SwiftUI
import StitchSchemaKit

@Observable
final class EdgeDrawingObserver {
    var nearestEligibleInput: InputNodeRowViewModel?
    var drawingGesture: OutputDragGesture?
    var recentlyDrawnEdge: PortEdgeUI?
}

extension EdgeDrawingObserver {
    func reset() {
        // MARK: we need equality checks to reduce render cycles
        
        if self.nearestEligibleInput != nil {
            self.nearestEligibleInput = nil
        }
        
        if self.drawingGesture != nil {
            self.drawingGesture = nil
        }
        
        if self.recentlyDrawnEdge != nil {
            self.recentlyDrawnEdge = nil
        }
    }
}

struct OutputDragGesture {
    // the output we started dragging from
    let output: OutputNodeRowViewModel
    var dragLocation: CGPoint

    // the diff of gesture.start;
    // set by SwiftUI drag gesture handlers,
    // since UIKit pan gesture gesture.location is inaccurate
    // for high velocities.
    var startingDiffFromCenter: CGSize
}

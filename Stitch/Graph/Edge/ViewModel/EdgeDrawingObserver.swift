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
    var nearestEligibleInput: NodeRowObserver?
    var drawingGesture: OutputDragGesture?
    var recentlyDrawnEdge: PortEdgeUI?
}

extension EdgeDrawingObserver {
    func reset() {
        self.nearestEligibleInput = nil
        self.drawingGesture = .none
        self.recentlyDrawnEdge = nil
    }
}

struct OutputDragGesture: Equatable {
    // the output we started dragging from
    let output: NodeRowObserver
    var dragLocation: CGPoint

    // the diff of gesture.start;
    // set by SwiftUI drag gesture handlers,
    // since UIKit pan gesture gesture.location is inaccurate
    // for high velocities.
    var startingDiffFromCenter: CGSize
}

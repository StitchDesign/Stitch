//
//  PortDragState.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/19/22.
//

import SwiftUI
import StitchSchemaKit

enum EligibleEdgeDestination {
    case canvasInput(InputNodeRowViewModel)
    case inspectorInputOrField(LayerInputType)
    
    var getCanvasInput: InputNodeRowViewModel? {
        switch self {
        case .canvasInput(let x):
            return nil
        default:
            return nil
        }
    }
    
    var getInspectorInputOrField: InputNodeRowViewModel? {
        switch self {
        case .inspectorInputOrField(let x):
            return nil
        default:
            return nil
        }
    }
}

@Observable
final class EdgeDrawingObserver: Sendable {
    
    // TODO: should these be exclusive i.e. an enum ? Can have eligible canvas input OR eligible inspector input/field ?
    @MainActor var nearestEligibleEdgeDestination: EligibleEdgeDestination?
    
    @MainActor var drawingGesture: OutputDragGesture?
    @MainActor var recentlyDrawnEdge: PortEdgeUI?
    
    @MainActor init() { }
}

extension EdgeDrawingObserver {
    @MainActor
    func reset() {
        // MARK: we need equality checks to reduce render cycles
        
        if self.nearestEligibleEdgeDestination != nil {
            self.nearestEligibleEdgeDestination = nil
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

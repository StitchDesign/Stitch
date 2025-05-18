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
            return x
        default:
            return nil
        }
    }
    
    var getInspectorInputOrField: LayerInputType? {
        switch self {
        case .inspectorInputOrField(let x):
            return x
        default:
            return nil
        }
    }
}

@Observable
final class EdgeDrawingObserver: Sendable {
    @MainActor var nearestEligibleEdgeDestination: EligibleEdgeDestination?
    @MainActor var drawingGesture: OutputDragGesture?

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
    }
}

@Observable
final class OutputDragGesture {
    // the output we started dragging from
    var outputId: NodeRowViewModelId
    
    // fka `dragLocation`
    var cursorLocationInGlobalCoordinateSpace: CGPoint

    // the diff of gesture.start;
    // set by SwiftUI drag gesture handlers,
    // since UIKit pan gesture gesture.location is inaccurate
    // for high velocities.
    var startingDiffFromCenter: CGSize
    
    init(outputId: NodeRowViewModelId,
         cursorLocationInGlobalCoordinateSpace: CGPoint,
         startingDiffFromCenter: CGSize) {
        self.outputId = outputId
        self.cursorLocationInGlobalCoordinateSpace = cursorLocationInGlobalCoordinateSpace
        self.startingDiffFromCenter = startingDiffFromCenter
    }
}

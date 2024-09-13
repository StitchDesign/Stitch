//
//  EdgeEditModeViewModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/1/24.
//

import StitchSchemaKit
import SwiftUI

// Only for outputs? So should be in NodeOutputView, not NodeInputOutputView
struct EdgeEditModeOutputViewModifier: ViewModifier {

    @Bindable var graphState: GraphState
    let portId: Int
    let canvasItemId: CanvasItemId?
    let forPropertySidebar: Bool

    @MainActor
    var isDraggingOutput: Bool {
        graphState.edgeDrawingObserver.drawingGesture.isDefined
    }

    func body(content: Content) -> some View {
                
        if let canvasItemId = canvasItemId,
           !forPropertySidebar {
            content
                .modifier(EdgeEditModeOutputHoverViewModifier(
                    graph: graphState,
                    outputCoordinate: .init(portId: portId, 
                                            canvasId: canvasItemId),
                    isDraggingOutput: isDraggingOutput))
        } else {
            content
        }
    }
}

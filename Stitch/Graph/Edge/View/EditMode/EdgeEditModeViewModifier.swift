//
//  EdgeEditModeViewModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/1/24.
//

import StitchSchemaKit
import SwiftUI

struct EdgeEditModeViewModifier: ViewModifier {

    @Bindable var graphState: GraphState
    let portId: Int
    let nodeId: CanvasItemId?
    let nodeIOType: NodeIO
    let forPropertySidebar: Bool

    @MainActor
    var isDraggingOutput: Bool {
        graphState.edgeDrawingObserver.drawingGesture.isDefined
    }

    func body(content: Content) -> some View {
                
        if let nodeId = nodeId,
            nodeIOType == .output,
           !forPropertySidebar {
            content
                .modifier(EdgeEditModeOutputHoverViewModifier(
                    graph: graphState,
                    outputCoordinate: .init(portId: portId, 
                                            canvasId: nodeId),
                    isDraggingOutput: isDraggingOutput))
        } else {
            content
        }
    }
}

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
    let portId: Int?
    let nodeId: NodeId
    let nodeIOType: NodeIO

    @MainActor
    var isDraggingOutput: Bool {
        graphState.edgeDrawingObserver.drawingGesture.isDefined
    }

    func body(content: Content) -> some View {
                
        if let portId = portId, nodeIOType == .output {
            content
                .modifier(EdgeEditModeOutputHoverViewModifier(
                    graph: graphState,
                    outputCoordinate: .init(portId: portId, 
                                            nodeId: nodeId),
                    isDraggingOutput: isDraggingOutput))
        } else {
            content
        }
    }
}

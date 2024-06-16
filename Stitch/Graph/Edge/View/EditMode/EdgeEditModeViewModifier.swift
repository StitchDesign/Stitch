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
    let coordinate: PortViewType

    @MainActor
    var isDraggingOutput: Bool {
        graphState.edgeDrawingObserver.drawingGesture.isDefined
    }

    func body(content: Content) -> some View {
        switch coordinate {
        case .input:
            content
        case .output(let outputPortViewData):
            content
                .modifier(EdgeEditModeOutputHoverViewModifier(
                    graph: graphState,
                    outputCoordinate: outputPortViewData,
                    nodeIO: coordinate.nodeIO,
                    isDraggingOutput: isDraggingOutput))
        }
    }
}

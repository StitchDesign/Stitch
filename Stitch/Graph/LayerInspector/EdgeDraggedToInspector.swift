//
//  EdgeDraggedToInspector.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/13/25.
//

import SwiftUI

enum EdgeDraggedToInspector: Hashable, Equatable {

    // TODO: currently this is stored for *every* output on the canvas; would be better to either (1) only use this for the actively-dragged-output or (2) reuse the existing `OutputPortUIViewModel.anchorPoints` (requires shifting anchorPoints to a global coordinate space)
    // Used for the actively-dragged output
    case draggedOutput(OutputCoordinate)
    
    // TODO: reuse the existing .global space
    // LayerInputType = could be for input or input-field
    // Note: the LayerInputType will always be for a
    case inspectorInputOrField(LayerInputType)
}

struct EdgeDraggedToInspectorPreferenceKey: PreferenceKey {
    static let defaultValue: [EdgeDraggedToInspector: Anchor<CGRect>] = [:]
    
    static func reduce(value: inout [EdgeDraggedToInspector: Anchor<CGRect>],
                       nextValue: () -> [EdgeDraggedToInspector: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func trackEdgeDraggedToInspectorAnchorPreference(id: EdgeDraggedToInspector,
                                                     shouldTrack: Bool = false) -> some View {
        self.anchorPreference(key: EdgeDraggedToInspectorPreferenceKey.self,
                              value: .bounds) {
            // TODO: does this if/else condition make a difference?
            // if shouldTrack {
                return [id: $0]
//            } else {
//                return [:] // Will this still trigger GeometryPoints etc. ?
//            }
        }
    }
}

// Only used in
struct TrackDraggedOutput: ViewModifier {
    let graph: GraphState
    let id: NodeIOCoordinate
    let nodeIO: NodeIO
    
    var isActivelyDraggedOutput: Bool {
        let activeDrag = graph.edgeDrawingObserver.drawingGesture?.outputId.asNodeIOCoordinate
        return self.id == activeDrag
    }
    
    func body(content: Content) -> some View {
        if nodeIO == .output {
            content.trackEdgeDraggedToInspectorAnchorPreference(
                id: .draggedOutput(id),
                shouldTrack: isActivelyDraggedOutput)
        } else {
            content
        }
    }
}

// Only used in inspector
struct TrackInspectorInput: ViewModifier {
    
    // Some inspector rows are for outputs, which we ignore
    let layerInputObserver: LayerInputObserver?
    
    // Are we actively dragging an input/output ?
    let hasActivelyDrawnEdge: Bool
    
    // Disabled when used e.g. in generic flyout row
    let disabled: Bool
    
    func body(content: Content) -> some View {
        if let layerInputObserver = layerInputObserver,
           !disabled {
            content.trackEdgeDraggedToInspectorAnchorPreference(
                id: .inspectorInputOrField(LayerInputType(layerInput: layerInputObserver.port,
                                                          portType: .packed)),
                shouldTrack: hasActivelyDrawnEdge)
        } else {
            content
        }
    }
}


struct TrackInspectorField: ViewModifier {
    
    // Some inspector rows are for outputs, which we ignore
    let layerInputObserver: LayerInputObserver
    let layerInputType: LayerInputType
    let usesMultifields: Bool
    
    // Are we actively dragging an input/output ?
    let hasActivelyDrawnEdge: Bool
    
    func body(content: Content) -> some View {

        // TODO: can this help with perf, if we don't track unless we have an active edge drag?
//        if hasActivelyDrawnEdge {
        if usesMultifields {
            content.trackEdgeDraggedToInspectorAnchorPreference(
                id: .inspectorInputOrField(layerInputType),
                shouldTrack: hasActivelyDrawnEdge)
        } else {
            content
        }
    }
}

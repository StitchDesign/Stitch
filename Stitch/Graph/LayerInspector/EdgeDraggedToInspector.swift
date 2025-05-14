//
//  EdgeDraggedToInspector.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/13/25.
//

import SwiftUI

enum EdgeDraggedToInspector: Hashable, Equatable {
    
    // TODO: MAY 13: also need for dragged input?
    case draggedOutput(OutputCoordinate)
    
    // LayerInputType = could be for input or input-field
    // Note: the LayerInputType will always be for a
    case inspectorInputOrField(LayerInputType)
}

extension String {
    static let DRAGGED_OUTPUT = "DRAGGED_OUTPUT"
    static let SIZE_INPUT = "SIZE_INPUT"
}

struct EdgeDraggedToInspectorPreferenceKey: PreferenceKey {
    static let defaultValue: [EdgeDraggedToInspector: Anchor<CGRect>] = [:]
    
    static func reduce(value: inout [EdgeDraggedToInspector: Anchor<CGRect>],
                       nextValue: () -> [EdgeDraggedToInspector: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func trackEdgeDraggedToInspectorAnchorPreference(id: EdgeDraggedToInspector) -> some View {
        self.anchorPreference(key: EdgeDraggedToInspectorPreferenceKey.self,
                              value: .bounds) {
            [id: $0]
        }
    }
}

struct TrackDraggedOutput: ViewModifier {
    let id: OutputCoordinate? // nil = was for input
    let isActivelyDraggedOutput: Bool
    
    func body(content: Content) -> some View {
        if let id = id,
            isActivelyDraggedOutput {
            content.trackEdgeDraggedToInspectorAnchorPreference(id: .draggedOutput(id))
        } else {
            content
        }
    }
}

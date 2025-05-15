//
//  EdgeDraggedToInspector.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/13/25.
//

import SwiftUI

enum EdgeDraggedToInspector: Hashable, Equatable {
    
    // TODO: MAY 13: NOT NEEDED?
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
    func trackEdgeDraggedToInspectorAnchorPreference(id: EdgeDraggedToInspector,
                                                     shouldTrack: Bool = false) -> some View {
        self.anchorPreference(key: EdgeDraggedToInspectorPreferenceKey.self,
                              value: .bounds) {
//            if shouldTrack {
                return [id: $0]
//            } else {
//                return [:] // Will this still trigger GeometryPoints etc. ?
//            }
        }
    }
}

// Only used in
struct TrackDraggedOutput: ViewModifier {
    let id: OutputCoordinate? // nil = was for input
    let isActivelyDraggedOutput: Bool
    
    func body(content: Content) -> some View {
        if let id = id {
            content.trackEdgeDraggedToInspectorAnchorPreference(id: .draggedOutput(id),
                                                                shouldTrack: isActivelyDraggedOutput)
        } else {
            content
        }
    }
}

// Only used in inspector
struct TrackInspectorInputOrField: ViewModifier {
    
    // Some inspector rows are for outputs, which we ignore
    let layerInputObserver: LayerInputObserver?
    
    let fieldIndex: Int?
    
    // Are we actively dragging an input/output ?
    let hasActivelyDrawnEdge: Bool
    
    func body(content: Content) -> some View {

        if let layerInputObserver = layerInputObserver {
            
            let layerInputType: LayerInputType = fieldIndex
                .map({ LayerInputType(layerInput: layerInputObserver.port,
                                      portType: .unpacked($0.asUnpackedPortType)) })
            ?? LayerInputType(layerInput: layerInputObserver.port,
                              portType: .packed)
            
            content.trackEdgeDraggedToInspectorAnchorPreference(
                id: .inspectorInputOrField(layerInputType),
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
    
    // Are we actively dragging an input/output ?
    let hasActivelyDrawnEdge: Bool
    
    func body(content: Content) -> some View {

//        if hasActivelyDrawnEdge {
        if true {
            content.trackEdgeDraggedToInspectorAnchorPreference(
                id: .inspectorInputOrField(layerInputType),
                shouldTrack: hasActivelyDrawnEdge)
        } else {
            content
        }
    }
}

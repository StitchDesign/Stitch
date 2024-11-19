//
//  NodePositionHandler.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/15/22.
//

import SwiftUI
import StitchSchemaKit

struct CanvasItemPositionHandler: ViewModifier {
    @Bindable var document: StitchDocumentViewModel
    
    @MainActor
    private var graphUI: GraphUIState {
        self.document.graphUI
    }
    
    @Bindable var node: CanvasItemViewModel
    
    @MainActor
    var isOptionPressed: Bool {
        document.keypressState.isOptionPressed
    }
    
    // ZIndex:
    let zIndex: ZIndex
    
    let usePositionHandler: Bool
    
    // When this node is the last selected node on graph,
    // we raise it and its buttons
    var _zIndex: ZIndex {
        //        zIndex + (isLastSelected ? NODE_IS_LAST_SELECTED_ZINDEX_BOOST : 0)
        zIndex
    }
    
    func body(content: Content) -> some View {
        if !usePositionHandler {
            content
        }  else {
            content
                .zIndex(_zIndex)
                .canvasPosition(id: node.id,
                                position: node.position)
            
            // MARK: we used to support node touch-down gesture with a hack using long press but this had averse effects on pinch
                .gesture(
                    DragGesture(
                        // minimumDistance: 0, // messes up trackpad pinch
                        // .global means we must consider zoom in `NodeMoved`
                        coordinateSpace: .global)
                    
                    .onChanged { gesture in
                        // log("NodePositionHandler: onChanged")
                        if isOptionPressed,
                           let nodeId = node.id.nodeCase {
                            dispatch(NodeDuplicateDraggedAction(
                                id: nodeId,
                                translation: gesture.translation))
                        } else {
                            document.visibleGraph.canvasItemMoved(for: node,
                                                                  translation: gesture.translation,
                                                                  wasDrag: true)
                        }
                    }
                        .onEnded { _ in
                            // log("NodePositionHandler: onEnded")
                            dispatch(NodeMoveEndedAction(id: node.id))
                        }
                ) // .gesture
        }
        //            .disabled(!usePositionHandler)
    }
}

extension View {
    /// Handles node position, drag gestures, and option+select for duplicating node.
    func canvasItemPositionHandler(document: StitchDocumentViewModel,
                                   node: CanvasItemViewModel,
                                   zIndex: ZIndex,
                                   usePositionHandler: Bool) -> some View {
        self.modifier(CanvasItemPositionHandler(document: document,
                                                node: node,
                                                zIndex: zIndex,
                                                usePositionHandler: usePositionHandler))
    }
}

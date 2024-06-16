//
//  NodePositionHandler.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/15/22.
//

import SwiftUI
import StitchSchemaKit

struct NodePositionHandler: ViewModifier {
    @Bindable var graph: GraphState
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }

    @Bindable var node: NodeViewModel
    let position: CGPoint

    @MainActor
    var isOptionPressed: Bool {
        graphUI.keypressState.isOptionPressed
    }

    // ZIndex:
    let zIndex: ZIndex

    let usePositionHandler: Bool

    var nodeId: NodeId {
        node.id
    }

    // When this node is the last selected node on graph,
    // we raise it and its buttons
    var _zIndex: ZIndex {
        //        zIndex + (isLastSelected ? NODE_IS_LAST_SELECTED_ZINDEX_BOOST : 0)
        zIndex
    }

    func body(content: Content) -> some View {

        if !usePositionHandler {
            content
        } else {
            content
                .zIndex(_zIndex)
                .position(position)

                // MARK: we used to support node touch-down gesture with a hack using long press but this had averse effects on pinch
                .gesture(
                    DragGesture(
                        // minimumDistance: 0, // messes up trackpad pinch
                        // .global means we must consider zoom in `NodeMoved`
                        coordinateSpace: .global)

                        .onChanged { gesture in
                            // log("NodePositionHandler: onChanged")
                            if isOptionPressed {
                                dispatch(NodeDuplicateDraggedAction(
                                            id: nodeId,
                                            translation: gesture.translation))
                            } else {
                                graph.nodeMoved(for: node,
                                                translation: gesture.translation,
                                                wasDrag: true)
                            }
                        }
                        .onEnded { _ in
                            // log("NodePositionHandler: onEnded")
                            dispatch(NodeMoveEndedAction(id: nodeId))
                        }
                ) // .gesture
        }
    }
}

extension View {
    /// Handles node position, drag gestures, and option+select for duplicating node.
    func nodePositionHandler(graph: GraphState,
                             node: NodeViewModel,
                             position: CGPoint,
                             zIndex: ZIndex,
                             usePositionHandler: Bool) -> some View {

        self.modifier(NodePositionHandler(graph: graph,
                                          node: node,
                                          position: position,
                                          zIndex: zIndex,
                                          usePositionHandler: usePositionHandler))
    }
}

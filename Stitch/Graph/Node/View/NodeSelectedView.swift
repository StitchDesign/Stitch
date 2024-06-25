//
//  NodeSelectedView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

struct NodeSelectedView: ViewModifier {

    @Environment(\.appTheme) var theme

    let isSelected: Bool

    // must use slightly larger corner radius for highlight
    let NODE_SELECTED_CORNER_RADIUS = NODE_CORNER_RADIUS + 3

    func body(content: Content) -> some View {
        let color = isSelected ? theme.themeData.highlightedEdgeColor : Color.clear
        return content
            .padding(3)
            .overlay {
                // needs to be slightly larger than
                RoundedRectangle(cornerRadius: NODE_SELECTED_CORNER_RADIUS)
                    .strokeBorder(color, lineWidth: 3)
            }
    }
}

// https://stackoverflow.com/questions/60407125/swiftui-how-can-i-detect-if-two-views-are-intersecting-each-other

struct NodeBoundsReader: ViewModifier {
    @Environment(\.viewframe) private var viewframe
    @Bindable var graph: GraphState
    @Bindable var canvasNode: CanvasNodeViewModel
    
    let splitterType: SplitterType?
    let disabled: Bool
    let updateMenuActiveSelectionBounds: Bool

    @MainActor
    var activeIndex: ActiveIndex {
        graph.graphUI.activeIndex
    }

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        // Track node bounds for visibility in frame
                        .onChange(of: proxy.frame(in: .named(GraphBaseView.coordinateNamespace)),
                                  initial: true) { _, newBounds in
                            if !disabled {
                                // log("will update GraphBaseView bounds for \(id)")
                               graph.updateGraphBaseViewBounds(
                                   for: canvasNode,
                                   newBounds: newBounds,
                                   viewFrame: viewframe,
                                   splitterType: splitterType,
                                   updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds)
                            }
                        }
                        .onChange(of: proxy.frame(in: .local),
                                  initial: true) { _, newBounds in
                            if !disabled {
                                // log("will update local bounds for \(id)")

                                // Used only for comment box creation
                                canvasNode.bounds.localBounds = newBounds
                            }
                        }
                }
            }
    }
}

/*
 There seems to be some problem with updating the `let nodeViewModel: NodeViewModel` or even `@Bindable var nodeViewModel: NodeViewModel` from directly inside `NodeBoundsReader`.

 For example, after graph reset, we would clearly update the node view model's bounds, but as soon as we went to use the node cursor selection box, the same node view model supposedly had the same bounds as it had been initialized with after graph reset.

 Simply switching to either a GraphEvent action or a method on `@Environment graph` resolved the issue; no other changes required.
 */
extension GraphState {
    /*
     We should keep a group node's input and output splitter nodes' subscriptions running, even when the splitter node is not on screen -- otherwise the group node's input and output ports stop updating.
     */
    @MainActor
    func updateGraphBaseViewBounds(for canvasObserver: CanvasNodeViewModel,
                                   newBounds: CGRect,
                                   viewFrame: CGRect,
                                   splitterType: SplitterType?,
                                   updateMenuActiveSelectionBounds: Bool) {
        
        

        // Note: do this *first*, since during node menu update we might not have a node view model for the node id yet
        if updateMenuActiveSelectionBounds {
            self.graphUI.insertNodeMenuState.activeSelectionBounds = newBounds
        }

        guard let nodeViewModel = self.getNodeViewModel(id) else {
            log("updateGraphBaseViewBounds: could not retrieve node \(id)")
            return
        }

        canvasObserver.bounds.graphBaseViewBounds = newBounds

        // See if it's in the visible frame
        let isVisibleInFrame = viewFrame.intersects(newBounds)
        canvasObserver.updateVisibilityStatus(with: isVisibleInFrame,
                                              activeIndex: activeIndex)
    }
}

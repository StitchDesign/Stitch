//
//  NodeSelectedView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

// fka `NodeSelectedView`
struct CanvasItemSelectedViewModifier: ViewModifier {

    @Environment(\.appTheme) var theme

    let isSelected: Bool

    // must use slightly larger corner radius for highlight
//    let CANVAS_ITEM_SELECTED_CORNER_RADIUS = CANVAS_ITEM_CORNER_RADIUS + 3
    let CANVAS_ITEM_SELECTED_CORNER_RADIUS = CANVAS_ITEM_CORNER_RADIUS + 6

    func body(content: Content) -> some View {
        let color = isSelected ? theme.themeData.highlightedEdgeColor : Color.clear
        return content
//            .padding(3)
//            .padding(7)
            .padding(6)
            .overlay {
                // needs to be slightly larger than
                RoundedRectangle(cornerRadius: CANVAS_ITEM_SELECTED_CORNER_RADIUS)
                    .strokeBorder(color, lineWidth: 3)
            }
    }
}

// https://stackoverflow.com/questions/60407125/swiftui-how-can-i-detect-if-two-views-are-intersecting-each-other

// fka `NodeBoundsReader`
struct CanvasItemBoundsReader: ViewModifier {
    @Environment(\.viewframe) private var viewframe
    @Bindable var graph: GraphState
    @Bindable var canvasItem: CanvasItemViewModel
    
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
                                   for: canvasItem,
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
                                canvasItem.bounds.localBounds = newBounds
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
    func updateGraphBaseViewBounds(for canvasItem: CanvasItemViewModel,
                                   newBounds: CGRect,
                                   viewFrame: CGRect,
                                   splitterType: SplitterType?,
                                   updateMenuActiveSelectionBounds: Bool) {

        // Note: do this *first*, since during node menu update we might not have a node view model for the node id yet
        if updateMenuActiveSelectionBounds {
            self.graphUI.insertNodeMenuState.activeSelectionBounds = newBounds
        }

        canvasItem.bounds.graphBaseViewBounds = newBounds

        // See if it's in the visible frame
        let isVisibleInFrame = viewFrame.intersects(newBounds)
        canvasItem.updateVisibilityStatus(with: isVisibleInFrame,
                                          activeIndex: activeIndex)
    }
}

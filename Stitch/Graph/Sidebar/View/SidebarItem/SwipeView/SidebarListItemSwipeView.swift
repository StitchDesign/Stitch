//
//  _SidebarListItemSwipeView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit

struct SidebarListItemSwipeView: View {
    @Bindable var graph: GraphState
    
    @StateObject var gestureViewModel: SidebarItemGestureViewModel

    var item: SidebarListItem
    let name: String
    let layer: Layer
    var current: SidebarDraggedItem?
    var proposedGroup: ProposedGroup?
    var isClosed: Bool
    let selection: SidebarListItemSelectionStatus
    let isBeingEdited: Bool

    @Binding var activeGesture: SidebarListActiveGesture

    @Binding var activeSwipeId: SidebarListItemId?

    @State var isHovered = false
    
    init(graph: Bindable<GraphState>,
         item: SidebarListItem,
         name: String,
         layer: Layer,
         current: SidebarDraggedItem? = nil,
         proposedGroup: ProposedGroup? = nil,
         isClosed: Bool,
         selection: SidebarListItemSelectionStatus,
         isBeingEdited: Bool,
         activeGesture: Binding<SidebarListActiveGesture>,
         activeSwipeId: Binding<SidebarListItemId?> = .constant(nil)) {
        
        self._graph = graph

        self.item = item
        self.name = name
        self.layer = layer
        self.current = current
        self.proposedGroup = proposedGroup
        self.isClosed = isClosed
        self.selection = selection
        self.isBeingEdited = isBeingEdited
        self._activeGesture = activeGesture
        self._activeSwipeId = activeSwipeId

        self._gestureViewModel = StateObject(wrappedValue: SidebarItemGestureViewModel(item: item,
                                                                                       activeGesture: activeGesture,
                                                                                       activeSwipeId: activeSwipeId))
    }
    
    var body: some View {
        // TODO: why does drag gesture on Catalyst break if we remove this?
        SidebarListItemGestureRecognizerView(
            view: customSwipeItem,
            gestureViewModel: gestureViewModel,
            graph: graph,
            layerNodeId: item.id.asLayerNodeId)
        .height(CGFloat(CUSTOM_LIST_ITEM_VIEW_HEIGHT))
        .padding(.horizontal, 4)
        
        // More accurate: needs to come before the `.offset(y:)` modifier
        .onHover { hovering in
            // log("hovering: sidebar item \(item.id.id)")
            // log("hovering: \(hovering)")
            self.isHovered = hovering
            if hovering {
                dispatch(SidebarLayerHovered(layer: item.id.asLayerNodeId))
            } else {
                dispatch(SidebarLayerHoverEnded(layer: item.id.asLayerNodeId))
            }
        }
        .offset(y: item.location.y)
        
        #if targetEnvironment(macCatalyst)
        // SwiftUI gesture handlers must come AFTER `.offset`
        .simultaneousGesture(gestureViewModel.macDragGesture)
        #else
        // SwiftUI gesture handlers must come AFTER `.offset`
        .onTapGesture { } // fixes long press + drag on iPad screen-touch
        // could also be a `.simultaneousGesture`?
        .gesture(gestureViewModel.longPressDragGesture)
        #endif
        .onChange(of: activeSwipeId) { _ in
            gestureViewModel.resetSwipePosition()
        }
        .onChange(of: isBeingEdited) { newValue in
            gestureViewModel.editOn = newValue
            gestureViewModel.resetSwipePosition()
        }
        .onChange(of: activeGesture) { newValue in
            switch newValue {
                // scrolling or dragging resets swipe-menu
            case .scrolling, .dragging:
                gestureViewModel.resetSwipePosition()
            default:
                return
            }
        }
    }

    // TODO: retrieve sidebar-width via a GeometryReader on whole sidebar rather than each individual item
    var customSwipeItem: some View {
        GeometryReader { geometry in
            SidebarListItemSwipeInnerView(
                graph: graph,
                item: item,
                name: name,
                layer: layer,
                current: current,
                proposedGroup: proposedGroup,
                isClosed: isClosed,
                selection: selection,
                isBeingEdited: isBeingEdited,
                swipeSetting: gestureViewModel.swipeSetting,
                sidebarWidth: geometry.size.width,
                isHovered: isHovered,
                gestureViewModel: gestureViewModel)
            .padding(1) // ensures .clipped doesn't cut off proposed-group border
            .clipped() // ensures edit buttons don't animate outside sidebar
        }
    }
}

//#Preview {
//    _SidebarListItemSwipeButton(action: nil,
//                               sfImageName: "ellipsis.circle",
//                               backgroundColor: .red,
//                               willLeftAlign: false)
//}

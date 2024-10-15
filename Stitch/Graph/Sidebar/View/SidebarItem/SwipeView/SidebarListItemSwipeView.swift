//
//  _SidebarListItemSwipeView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit

struct SidebarListItemSwipeView<GestureViewModel: SidebarItemSwipable>: View {
    @Bindable var graph: GraphState
    
    @State var gestureViewModel: GestureViewModel

    var item: GestureViewModel.Item
    
    let name: String
//    let layer: Layer
    var current: SidebarDraggedItem<GestureViewModel.Item.ID>?
    var proposedGroup: ProposedGroup<GestureViewModel.Item.ID>?
    var isClosed: Bool
    let selection: SidebarListItemSelectionStatus
    let isBeingEdited: Bool

    @Binding var activeGesture: GestureViewModel.ActiveGesture

    @Binding var activeSwipeId: GestureViewModel.Item.ID?

//    init(graph: Bindable<GraphState>,
//         item: SidebarListItem,
//         name: String,
//         layer: Layer,
//         current: SidebarDraggedItem? = nil,
//         proposedGroup: ProposedGroup? = nil,
//         isClosed: Bool,
//         selection: SidebarListItemSelectionStatus,
//         isBeingEdited: Bool,
//         activeGesture: Binding<SidebarListActiveGesture>,
//         activeSwipeId: Binding<SidebarListItemId?> = .constant(nil)) {
//        
//        self._graph = graph
//
//        self.item = item
//        self.name = name
//        self.layer = layer
//        self.current = current
//        self.proposedGroup = proposedGroup
//        self.isClosed = isClosed
//        self.selection = selection
//        self.isBeingEdited = isBeingEdited
//        self._activeGesture = activeGesture
//        self._activeSwipeId = activeSwipeId
//
//        self._gestureViewModel = StateObject(wrappedValue: SidebarItemGestureViewModel(item: item,
//                                                                                       activeGesture: activeGesture,
//                                                                                       activeSwipeId: activeSwipeId))
//    }
    
    var body: some View {
        // TODO: why does drag gesture on Catalyst break if we remove this?
        SidebarListItemGestureRecognizerView(
            view: customSwipeItem,
            gestureViewModel: gestureViewModel,
            graph: graph,
            itemId: item.id)
        .height(CGFloat(CUSTOM_LIST_ITEM_VIEW_HEIGHT))
        .padding(.horizontal, 4)
        .offset(y: gestureViewModel.location.y)
        
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
//                layer: layer,
                current: current,
                proposedGroup: proposedGroup,
                isClosed: isClosed,
                selection: selection,
                isBeingEdited: isBeingEdited,
                swipeSetting: gestureViewModel.swipeSetting,
                sidebarWidth: geometry.size.width,
                gestureViewModel: gestureViewModel)
            .onHover { hovering in
                // log("hovering: sidebar item \(item.id.id)")
                // log("hovering: \(hovering)")
                if hovering {
                    self.gestureViewModel.sidebarLayerHovered(itemId: item.id)
                } else {
                    self.gestureViewModel.sidebarLayerHoverEnded(itemId: item.id)
                }
            }
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

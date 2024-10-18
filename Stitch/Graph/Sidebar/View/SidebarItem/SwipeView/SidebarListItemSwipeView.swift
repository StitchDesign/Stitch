//
//  _SidebarListItemSwipeView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit

struct SidebarListItemSwipeView<SidebarViewModel>: View where SidebarViewModel: ProjectSidebarObservable {
    typealias ItemViewModel = SidebarViewModel.ItemViewModel
    
    @Bindable var graph: GraphState
    @Bindable var sidebarViewModel: SidebarViewModel
    @Bindable var gestureViewModel: ItemViewModel
    
    var body: some View {
        // TODO: why does drag gesture on Catalyst break if we remove this?
        SidebarListItemGestureRecognizerView(
            view: customSwipeItem,
            sidebarViewModel: sidebarViewModel,
            gestureViewModel: gestureViewModel,
            graph: graph)
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

        .onChange(of: sidebarViewModel.activeSwipeId) {
            gestureViewModel.resetSwipePosition()
        }
        .onChange(of: sidebarViewModel.isEditing) {
            gestureViewModel.resetSwipePosition()
        }
        .onChange(of: sidebarViewModel.activeGesture) { _, newValue in
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
                sidebarViewModel: sidebarViewModel,
                itemViewModel: gestureViewModel,
                sidebarWidth: geometry.size.width)
            .onHover { hovering in
                // log("hovering: sidebar item \(item.id.id)")
                // log("hovering: \(hovering)")
                if hovering {
                    self.gestureViewModel.sidebarLayerHovered(itemId: gestureViewModel.id)
                } else {
                    self.gestureViewModel.sidebarLayerHoverEnded(itemId: gestureViewModel.id)
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

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
    
    @Environment(\.appTheme) private var theme
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var sidebarViewModel: SidebarViewModel
    @Bindable var gestureViewModel: ItemViewModel
    
    var isSidebarFocused: Bool {
        self.sidebarViewModel.isSidebarFocused
    }
    
    var isSelected: Bool {
        self.sidebarViewModel.primary.contains(gestureViewModel.id)
    }
    
    var isParentSelected: Bool {
        self.gestureViewModel.isParentSelected(sidebar: sidebarViewModel)
    }
    
    var yOffset: CGFloat {
        guard let dragPosition = gestureViewModel.dragPosition else {
            return gestureViewModel.location.y
        }
        
        return dragPosition.y
    }
    
    var indentationPadding: Int {
        CUSTOM_LIST_ITEM_INDENTATION_LEVEL * gestureViewModel.sidebarIndex.groupIndex
    }
    
    // Controls animation for non-dragged elements
    var animationDuration: Double {
        gestureViewModel.isBeingDragged ? 0 : 0.25
    }
    
    var backgroundOpacity: Double {
        if isSelected {
            return isSidebarFocused ? 1 : 0.5
        }
        
        if isParentSelected && sidebarViewModel.currentItemDragged != nil {
            return 0.5
        }
        
        return 0
    }
    
    var body: some View {
        // TODO: why does drag gesture on Catalyst break if we remove this?
        SidebarListItemGestureRecognizerView(
            view: customSwipeItem,
            sidebarViewModel: sidebarViewModel,
            gestureViewModel: gestureViewModel)
        .transition(.move(edge: .top).combined(with: .opacity))
        
        // MARK: indent padding animation needs to be before y animation
        .animation(.stitchAnimation(duration: 0.25), value: indentationPadding)
        .animation(.stitchAnimation(duration: animationDuration), value: gestureViewModel.location.y)
        
        .zIndex(gestureViewModel.zIndex)
        .height(CGFloat(CUSTOM_LIST_ITEM_VIEW_HEIGHT))
        .padding(.horizontal, 4)
        .padding(.leading, CGFloat(indentationPadding))
        .background {
            theme.fontColor
                .opacity(backgroundOpacity)
        }
        .onHover { [weak gestureViewModel] hovering in
            // MARK: - SUPER DUPER IMPORTANT TO WEAKLY REFERENCE **EVERYTHING** ELSE SEE RETAIN CYCLES
            
            guard let gestureViewModel = gestureViewModel else { return }
            
            gestureViewModel.isHovered = hovering
            if hovering {
                if !self.sidebarViewModel.highlightedSidebarLayers.contains(gestureViewModel.id) {
                    self.sidebarViewModel.highlightedSidebarLayers.insert(gestureViewModel.id)
                }
            } else {
                if self.sidebarViewModel.highlightedSidebarLayers.contains(gestureViewModel.id) {
                    self.sidebarViewModel.highlightedSidebarLayers.remove(gestureViewModel.id)
                }
            }
        }
        
        // MARK: - offset must come after hover and before gestures for dragging to work!
        .offset(y: yOffset)
        
#if targetEnvironment(macCatalyst)
        // SwiftUI gesture handlers must come AFTER `.offset`
        .simultaneousGesture(gestureViewModel.macDragGesture(sidebar: self.sidebarViewModel))
#else
        // SwiftUI gesture handlers must come AFTER `.offset`
        .onTapGesture { } // fixes long press + drag on iPad screen-touch
        // could also be a `.simultaneousGesture`?
        .gesture(gestureViewModel.longPressDragGesture(sidebar: self.sidebarViewModel))
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
        SidebarListItemSwipeInnerView(
            graph: graph,
            document: document,
            sidebarViewModel: sidebarViewModel,
            itemViewModel: gestureViewModel)
        .padding(1) // ensures .clipped doesn't cut off proposed-group border
        .clipped() // ensures edit buttons don't animate outside sidebar
    }
}

//#Preview {
//    _SidebarListItemSwipeButton(action: nil,
//                               sfImageName: "ellipsis.circle",
//                               backgroundColor: .red,
//                               willLeftAlign: false)
//}

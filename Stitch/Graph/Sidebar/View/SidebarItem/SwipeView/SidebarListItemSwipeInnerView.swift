//
//  SidebarListItemSwipeInnerView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SidebarListItemSwipeInnerView<SidebarViewModel>: View where SidebarViewModel: ProjectSidebarObservable {
    // The actual rendered distance for the swipe distance
    @State private var swipeX: Double = 0
    @State private var sidebarWidth: Double = .zero
    
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    @Bindable var sidebarViewModel: SidebarViewModel
    @Bindable var itemViewModel: SidebarViewModel.ItemViewModel
    
    var showMainItem: Bool { swipeX < DEFAULT_ACTION_THRESHOLD }
    
    var isBeingEdited: Bool {
        self.sidebarViewModel.isEditing
    }
    
    var isHidden: Bool {
        self.itemViewModel.isHidden
    }
    
    var body: some View {
        HStack(spacing: .zero) {
            // Main row hides if swipe menu exceeds threshold
            if showMainItem {
                SidebarListItemView(graph: graph,
                                    graphUI: graphUI,
                                    sidebarViewModel: sidebarViewModel,
                                    item: itemViewModel,
                                    swipeOffset: swipeX,
                                    fontColor: fontColor)
                // right-side label overlay comes AFTER x-placement of item,
                // so as not to be affected by x-placement.
                .overlay(alignment: .trailing) {
                    
#if !targetEnvironment(macCatalyst)
                    SidebarListItemRightLabelView(
                        item: itemViewModel,
                        isBeingEdited: sidebarViewModel.isEditing,
                        fontColor: fontColor)
                    .frame(height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
#endif
                    
//                    // TODO: revisit this; currently still broken on Catalyst and the UIKitTappableWrapper becomes unresponsive as soon as we apply a SwiftUI .frame or .offset; `Spacer()`s also do not seem to work
//                    // Hovering can happen on either Catalyst or iPad
//                    if isHovered {
//                        HStack {
//                            Spacer()
//                            UIKitTappableWrapper {
//                                log("clicked hover icon for \(layerNodeId)")
//                                dispatch(SidebarItemHiddenStatusToggled(clickedId: layerNodeId))
//                            } view: {
//                                Spacer()
//                                Image(systemName: isHidden ? SIDEBAR_VISIBILITY_STATUS_HIDDEN_ICON : SIDEBAR_VISIBILITY_STATUS_VISIBLE_ICON)
//                                    .foregroundColor(fontColor)
//                            }
//                        } // HStack
//                    } // if isHovered
                    
                }
                .padding(.trailing, 2)
            }
            
#if !targetEnvironment(macCatalyst)
            SidebarListItemSwipeMenu(
                gestureViewModel: itemViewModel,
                swipeOffset: swipeX)
#endif
        }
#if !targetEnvironment(macCatalyst)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        self.sidebarWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        if newWidth != self.sidebarWidth {
                            self.sidebarWidth = newWidth
                        }
                    }
            }
        }
#endif
        
        // Animates swipe distance if it gets pinned to its open or closed position.
        // Does NOT animate for normal swiping.
#if !targetEnvironment(macCatalyst)
        .onChange(of: self.itemViewModel.swipeSetting) { _, newSwipeSetting in
            switch newSwipeSetting {
            case .closed, .open:
                                
//                withAnimation { // has weird behavior at end of closing animation
                
//                withAnimation(.linear(duration: 0.1)) {
//                withAnimation(.easeInOut(duration: 0.2)) {
//                withAnimation(.easeInOut(duration: 0.3)) {
                
                // Feels just right?
                withAnimation(.easeInOut(duration: 0.25)) {
                    swipeX = newSwipeSetting.distance
                }
            case .swiping(let distance):
                swipeX = min(distance, sidebarWidth)
            }
        }
#endif
        .animation(.stitchAnimation(duration: 0.25), value: showMainItem)
    }
    
    @MainActor
    var fontColor: Color {
        let selection = self.itemViewModel.selectionStatus

#if DEV_DEBUG
        if itemViewModel.isHidden {
            return .purple
        }
#endif

        // Any 'focused' (doesn't have to be 'actively selected') layer uses white text
        if !self.isBeingEdited && itemViewModel.isSelected {
#if DEV_DEBUG
            return .red
#else
            return .white
#endif
        }

#if DEV_DEBUG
        // Easier to see secondary selections for debug
        //        return selection.color(isHidden)

        switch selection {
        case .primary:
            return .brown
        case .secondary:
            return .green
        case .none:
            return .blue
        }

#endif

        if isBeingEdited || isHidden {
            return self.getColor()
        } else {
            // i.e. if we are not in edit mode, do NOT show secondarily-selected layers (i.e. children of a primarily-selected parent) as gray
            return SIDE_BAR_OPTIONS_TITLE_FONT_COLOR
        }
    }
    
    // a secondarily- or hidden primarily-selected color has half the strength
    func getColor() -> Color {
        switch itemViewModel.selectionStatus {
        // both primary selection and non-selection use white;
        // the difference whether the circle gets filled or not
        case .primary, .none:
            // return .white
            return SIDE_BAR_OPTIONS_TITLE_FONT_COLOR.opacity(isHidden ? 0.5 : 1)
        case .secondary:
            return SIDE_BAR_OPTIONS_TITLE_FONT_COLOR.opacity(0.5)
        }
    }
}

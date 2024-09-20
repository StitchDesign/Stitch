//
//  _SidebarListView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI

// Entire Figma sidebar is 320 pixels wide
let SIDEBAR_WIDTH: CGFloat = 320

let SIDEBAR_LIST_ITEM_ICON_AND_TEXT_SPACING: CGFloat = 4.0

#if targetEnvironment(macCatalyst)
let SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT: CGFloat = 20.0
let SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT: CGFloat = 28.0
let SIDEBAR_LIST_ITEM_FONT: Font = STITCH_FONT // 14.53
#else
let SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT: CGFloat = 24.0
let SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT: CGFloat = 32.0
let SIDEBAR_LIST_ITEM_FONT: Font = stitchFont(18)
#endif


struct SidebarListView: View {

    @Bindable var graph: GraphState

    let isBeingEdited: Bool
    let syncStatus: iCloudSyncStatus

    @State var activeSwipeId: SidebarListItemId?
    @State var activeGesture: SidebarListActiveGesture = .none

    // Animated state
    @State var isBeingEditedAnimated = false

    var selections: SidebarSelectionState {
        graph.sidebarSelectionState
    }
    
    var sidebarListState: SidebarListState {
        graph.sidebarListState
    }
    
    var groups: SidebarGroupsDict {
        graph.getSidebarGroupsDict()
    }
    
    var sidebarDeps: SidebarDeps {
        SidebarDeps(
            layerNodes: .fromLayerNodesDict(
                nodes: graph.layerNodes,
                orderedSidebarItems: graph.orderedSidebarLayers),
            groups: groups,
            expandedItems: graph.getSidebarExpandedItems())
    }

    var layerNodesForSidebarDict: LayerNodesForSidebarDict {
        sidebarDeps.layerNodes
    }

    var masterList: SidebarListItemsCoordinator {
        sidebarListState.masterList
    }
    
    var body: some View {
        VStack(spacing: 0) {
            listView
            Spacer()
            // Note: previously was in an `.overlay(footer, alignment: .bottom)` which now seems unnecessary
            SidebarFooterView(groups: sidebarDeps.groups,
                               selections: selections,
                               isBeingEdited: isBeingEditedAnimated,
                               syncStatus: syncStatus,
                               layerNodes: layerNodesForSidebarDict)
        }
        // NOTE: only listen for changes to expandedItems or sidebar-groups,
        // not the layerNodes, since layerNodes change constantly
        // when eg a Time Node is attached to a Text Layer.
        .onChange(of: sidebarDeps.expandedItems, perform: { _ in
            activeSwipeId = nil
        })
        .onChange(of: sidebarDeps.groups, perform: { _ in
            activeSwipeId = nil
        })
        // TODO: see note in `DeriveSidebarList`
        .onChange(of: graph.nodes.keys.count) { _, _ in
            dispatch(DeriveSidebarList())
        }
    }

    // Note: sidebar-list-items is a flat list;
    // indentation is handled by calculated indentations.
    @MainActor
    var listView: some View {

        let current: SidebarDraggedItem? = sidebarListState.current

        return ScrollView(.vertical) {
            // use .topLeading ?
            ZStack(alignment: .leading) {
                
                // HACK
                if masterList.items.isEmpty {
                    fakeSidebarListItem
                }
                
                ForEach(masterList.items, id: \.id.value) { (item: SidebarListItem) in
                    
                    let selection = getSelectionStatus(
                        item.id.asLayerNodeId,
                        selections)
                    
                    SidebarListItemSwipeView(
                        graph: $graph,
                        item: item,
                        name: graph.getNodeViewModel(item.id.asNodeId)?.getDisplayTitle() ?? item.layer.value,
                        layer: layerNodesForSidebarDict[item.id.asLayerNodeId]?.layer ?? .rectangle,
                        current: current,
                        proposedGroup: sidebarListState.proposedGroup,
                        isClosed: masterList.collapsedGroups.contains(item.id),
                        selection: selection,
                        isBeingEdited: isBeingEditedAnimated,
                        activeGesture: $activeGesture,
                        activeSwipeId: $activeSwipeId)
                    .zIndex(item.zIndex)
                    .transition(.move(edge: .top).combined(with: .opacity))
                } // ForEach
                
            } // ZStack
            
            // Need to specify the amount space (height) the sidebar items all-together need,
            // so that scroll view doesn't interfere with e.g. tap gestures on views deeper inside
            // (e.g. the tap gesture on the circle in edit-mode)
            .frame(height: Double(CUSTOM_LIST_ITEM_VIEW_HEIGHT * masterList.items.count),
                   alignment: .top)
        
//            #if DEV_DEBUG
//            .border(.purple)
//            #endif
        } // ScrollView // added
        .scrollContentBackground(.hidden)
//        .background(WHITE_IN_LIGHT_MODE_GRAY_IN_DARK_MODE)
        
//        .background {
//            Color.yellow.opacity(0.5)
//        }
        
//        #if DEV_DEBUG
//        .border(.green)
//        #endif

        
#if !targetEnvironment(macCatalyst)
        .animation(.spring(), value: selections)
#endif
        // TODO: remove some of these animations ?
        .animation(.spring(), value: isBeingEdited)
        .animation(.spring(), value: sidebarListState.proposedGroup)
        .animation(.spring(), value: sidebarDeps)
        .animation(.easeIn, value: sidebarListState.masterList.items)
        
        .onChange(of: isBeingEdited) { newValue in
            // This handler enables all animations
            isBeingEditedAnimated = newValue
        }
        
    }
    
    // HACK for proper width even when sidebar is empty
    // TODO: revisit and re-organize UI to avoid this hack
    @ViewBuilder @MainActor
    var fakeSidebarListItem: some View {

        let item = SidebarListItem.fakeSidebarListItem

        SidebarListItemSwipeView(
            graph: $graph,
            item: item,
            name: item.layer.value,
            layer: .rectangle,
            current: .none,
            proposedGroup: .none,
            isClosed: true,
            selection: .none,
            isBeingEdited: false,
            activeGesture: $activeGesture,
            activeSwipeId: $activeSwipeId)
            .opacity(0)
    }
}

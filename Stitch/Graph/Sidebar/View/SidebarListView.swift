//
//  _SidebarListView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI

// Entire Figma sidebar is 320 pixels wide
let SIDEBAR_WIDTH: CGFloat = 320

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
    
    var sidebarDeps: SidebarDeps {
        SidebarDeps(
            layerNodes: .fromLayerNodesDict(
                nodes: graph.layerNodes,
                orderedSidebarItems: graph.orderedSidebarLayers),
            groups: graph.getSidebarGroupsDict(),
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
                    SidebarListItemSwipeView(
                        graph: $graph,
                        item: item,
                        name: graph.getNodeViewModel(item.id.asNodeId)?.getDisplayTitle() ?? item.layer.value,
                        layer: layerNodesForSidebarDict[item.id.asLayerNodeId]?.layer ?? .rectangle,
                        current: current,
                        proposedGroup: sidebarListState.proposedGroup,
                        isClosed: masterList.collapsedGroups.contains(item.id),
                        selection: getSelectionStatus(
                            item.id.asLayerNodeId,
                            selections),
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
        
//        #if DEV_DEBUG
//        .border(.green)
//        #endif
        
        .animation(.spring(), value: selections)
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

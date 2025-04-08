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
    static let tabs = ["Layers", "Assets"]
    @State private var currentTab = ProjectSidebarTab.layers.rawValue
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    let syncStatus: iCloudSyncStatus
    
    var body: some View {
        VStack {
            // TODO: re-enable tabs for asset manager
//            Picker("Sidebar Tabs", selection: self.$currentTab) {
//                ForEach(Self.tabs, id: \.self) { tab in
////                    HStack {
//                        //                        Image(systemName: tab.iconName)
//                        Text(tab)
//                        .width(200)
////                    }
//                }
//            }
//            .pickerStyle(.segmented)
            
            switch ProjectSidebarTab(rawValue: self.currentTab) {
            case .none:
                FatalErrorIfDebugView()
            case .some(let tab):
                switch tab {
                case .layers:
                    SidebarListScrollView(graph: graph,
                                          document: document,
                                          sidebarViewModel: graph.layersSidebarViewModel,
                                          tab: tab,
                                          syncStatus: syncStatus)
                case .assets:
                    FatalErrorIfDebugView()
                }
            }
        }
    }
}

struct SidebarListScrollView<SidebarObservable>: View where SidebarObservable: ProjectSidebarObservable {
    @State private var isBeingEditedAnimated = false
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var sidebarViewModel: SidebarObservable
    let tab: ProjectSidebarTab
    let syncStatus: iCloudSyncStatus
    
    var isBeingEdited: Bool {
        self.sidebarViewModel.isEditing
    }
    
    var body: some View {
        VStack(spacing: 0) {
            listView
            Spacer()
            SidebarFooterView(sidebarViewModel: sidebarViewModel,
                              syncStatus: syncStatus)
        }
    }
    
    // Note: sidebar-list-items is a flat list;
    // indentation is handled by calculated indentations.
    @MainActor
    var listView: some View {
        let allFlattenedItems = self.sidebarViewModel.getVisualFlattenedList()
        
        return ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                // HACK
                if allFlattenedItems.isEmpty {
                    Color.clear
                }
                
                ForEach(allFlattenedItems) { item in
                    SidebarListItemSwipeView(
                        graph: graph,
                        document: document,
                        sidebarViewModel: sidebarViewModel,
                        gestureViewModel: item)
                } // ForEach
                
            } // ZStack
            
            // Need to specify the amount space (height) the sidebar items all-together need,
            // so that scroll view doesn't interfere with e.g. tap gestures on views deeper inside
            // (e.g. the tap gesture on the circle in edit-mode)
            .frame(height: Double(CUSTOM_LIST_ITEM_VIEW_HEIGHT * allFlattenedItems.count),
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
        .toolbar {
            SidebarEditButtonView(sidebarViewModel: self.sidebarViewModel)
        }
#endif
        // TODO: remove some of these animations ?
        .animation(.spring(), value: isBeingEdited)        
        .onChange(of: isBeingEdited) { _, newValue in
            // This handler enables all animations
            isBeingEditedAnimated = newValue
        }
    }
}

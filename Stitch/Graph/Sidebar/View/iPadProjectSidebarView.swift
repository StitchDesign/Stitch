//
//  ProjectSidebarView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/14/22.
//

import SwiftUI
import StitchSchemaKit

let SIDEBAR_BODY_COLOR: Color = Color(.sideBarBody)
let SIDEBAR_HEADER_COLOR: Color = Color(.sideBarHeader)

struct StitchSidebarView: View {
    @Environment(StitchStore.self) var store

    let syncStatus: iCloudSyncStatus

    var body: some View {
        if let graph = store.currentDocument?.visibleGraph {
            ProjectSidebarView(graph: graph,
                               syncStatus: syncStatus)

        } else {
            Text("Coming soon: Stitch Components")
        }
    }
}

struct ProjectSidebarView: View {
    @State private var isEditing = false
    @Bindable var graph: GraphState
    let syncStatus: iCloudSyncStatus

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            
            SidebarListView(graph: graph,
                            isBeingEdited: isEditing,
                            syncStatus: syncStatus)
            //#if !targetEnvironment(macCatalyst)
            //            .padding(.top)
            //#endif
            .zIndex(1)
        }
//        .background(SIDEBAR_BODY_COLOR.ignoresSafeArea())
        
        // Needed so that sidebar-footer does not rise up when iPad full keyboard on-screen
        .edgesIgnoringSafeArea(.bottom)
        
        // iPad only
#if !targetEnvironment(macCatalyst)
        .navigationTitle("Stitch")
        .toolbar {
            SidebarEditButtonView(isEditing: $isEditing)
        }

        // Allows scrolled up content to be visible underneath other nav-stack icons; not ideal.
//        .toolbarBackground(.hidden, for: .automatic)
        
        // We can change the color of the sidebar's top-most section
        .toolbarBackground(.visible, for: .automatic)
        .toolbarBackground(Color.WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE, for: .automatic)
#endif
        
        .onChange(of: self.isEditing, initial: true) { _, newValue in
            dispatch(SidebarEditModeToggled(isEditing: newValue))
        }
    }
}

struct SidebarEditModeToggled: GraphEvent {
    let isEditing: Bool
    
    func handle(state: GraphState) {
        // Reset selection-state, but preserve inspector's focused layers
        let inspectorFocusedLayers = state.sidebarSelectionState.inspectorFocusedLayers
        
        // Don't actually reset these?
//        state.sidebarSelectionState.resetEditModeSelections()
        
        state.sidebarSelectionState.inspectorFocusedLayers = inspectorFocusedLayers
        
        // Do not set until the end; otherwise selection-state resets loses the change.
        state.sidebarSelectionState.isEditMode = isEditing
    }
}

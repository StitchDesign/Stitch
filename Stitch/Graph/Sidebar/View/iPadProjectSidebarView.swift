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
        if let document = store.currentDocument,
           let graph = store.currentDocument?.visibleGraph {
            ProjectSidebarView(graph: graph,
                               graphUI: document.graphUI,
                               syncStatus: syncStatus)

        } else {
            Text("Coming soon: Stitch Components")
        }
    }
}

struct ProjectSidebarView: View {
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    let syncStatus: iCloudSyncStatus

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            SidebarListView(graph: graph,
                            graphUI: graphUI,
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

        // Allows scrolled up content to be visible underneath other nav-stack icons; not ideal.
//        .toolbarBackground(.hidden, for: .automatic)
        
        // We can change the color of the sidebar's top-most section
        .toolbarBackground(.visible, for: .automatic)
        .toolbarBackground(Color.WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE, for: .automatic)
#endif
    }
}

extension LayersSidebarViewModel {
    func editModeToggled(to isEditing: Bool) {
        // Reset selection-state, but preserve inspector's focused layers
        
        // Don't actually reset these?
//        state.sidebarSelectionState.resetEditModeSelections()
        
//        self.inspectorFocusedLayers = inspectorFocusedLayers
        
        // Do not set until the end; otherwise selection-state resets loses the change.
//        self.selectionState.isEditMode = isEditing
    }
}

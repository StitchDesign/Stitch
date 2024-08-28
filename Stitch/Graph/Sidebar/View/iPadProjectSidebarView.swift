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
        if let graph = store.currentGraph {
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
            
            // Catalyst only
#if targetEnvironment(macCatalyst)
            VStack {
                HStack(spacing: .zero) {
                    // Padding HStack
                    HStack {
                        titleView
                        Spacer()
                        SidebarEditButtonView(isEditing: $isEditing)
                    }
                    .padding([.top, .horizontal])
                }
            }
            //            .padding(.bottom)
            .background(SIDEBAR_BODY_COLOR.ignoresSafeArea())
            // Higher z-index here for scroll view
            .zIndex(2)
#endif
            
            SidebarListView(graph: graph,
                            isBeingEdited: isEditing,
                            syncStatus: syncStatus)
            //#if !targetEnvironment(macCatalyst)
            //            .padding(.top)
            //#endif
            .zIndex(1)
        }
        .background(SIDEBAR_BODY_COLOR.ignoresSafeArea())
        
        // Needed so that sidebar-footer does not rise up when iPad full keyboard on-screen
        .edgesIgnoringSafeArea(.bottom)
        
        // iPad only
        // TODO: why is .navigationTitle ignored on Catalyst?
#if !targetEnvironment(macCatalyst)
        .navigationTitle("Stitch")
        .toolbar {
            SidebarEditButtonView(isEditing: $isEditing)
        }
        .toolbarBackground(.visible, for: .automatic)
#endif
        .onChange(of: self.isEditing) { _, newValue in
            dispatch(SidebarEditModeToggled(isEditing: newValue))
        }
    }

    var titleView: some View {
        Text("Stitch")
            .font(.largeTitle)
            .bold()

    }
}

struct SidebarEditModeToggled: GraphEvent {
    let isEditing: Bool
    
    func handle(state: GraphState) {
        if isEditing {
            state.sidebarSelectionState.nonEditModeSelections = .init()
        }
        
        if !isEditing {
            state.sidebarSelectionState = .init()
        }
    }
}

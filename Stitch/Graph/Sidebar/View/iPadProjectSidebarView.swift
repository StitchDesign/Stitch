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
                               document: document,
                               syncStatus: syncStatus)

        } else {
            ProjectSidebarEmptyView(document: nil)
        }
    }
}

struct ProjectSidebarView: View {
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    let syncStatus: iCloudSyncStatus

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            SidebarListView(graph: graph,
                            document: document,
                            syncStatus: syncStatus)
            //#if !targetEnvironment(macCatalyst)
            //            .padding(.top)
            //#endif
            .zIndex(1)
        }
        .background(Color.WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE.ignoresSafeArea())
        .onTapGesture {
            if document.reduxFocusedField != .sidebar {
                document.reduxFocusedField = .sidebar
            }
        }
        
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

struct ProjectSidebarEmptyView: View {
    static let title = "Layer Sidebar"
    
    let document: StitchDocumentViewModel?
    
    var body: some View {
        if let document = document {
            SidebarEmptyStateView(title: Self.title,
                                  description: "Layers will populate here.") {
                NodeEmptyStateAboutButtonsView(isPatch: false,
                                               document: document)
            }
        } else {
            SidebarEmptyStateView(title: Self.title,
                                  description: "Layers will populate here.") {
                EmptyView()
            }
        }
    }
}

struct NodeEmptyStateAboutButtonsView: View {
#if targetEnvironment(macCatalyst)
    static let defaultWidth: CGFloat = 200
    private static let defaultButtonWidth: CGFloat = 160
#else
    static let defaultWidth: CGFloat = 260
    private static let defaultButtonWidth: CGFloat = 200
#endif
    @State private var willShowAboutPopover = false
    
    let isPatch: Bool
    let document: StitchDocumentViewModel
    
    var label: String {
        isPatch ? "Patches" : "Layers"
    }
    
    var body: some View {
        Button {
            document.insertNodeMenuState.show = true
        } label: {
            Image(systemName: "uiwindow.split.2x1")
            Text("Insert Node")
            
            Spacer()
            
            KeyboardShortcutButtonLabel(imageNames: ["command", "return"])
        }
        .frame(width: Self.defaultButtonWidth)
        
        Button {
            self.willShowAboutPopover = true
        } label: {
            Image(systemName: "text.page")
            Text("About \(label)")
            
            Spacer()
        }
        .popover(isPresented: $willShowAboutPopover) {
            StitchDocsPopoverView(router: isPatch ? .patch(.header) : .layer(.header))
        }
        .frame(width: Self.defaultButtonWidth)
    }
}

// TODO: move
struct SidebarEmptyStateView<ButtonsView: View>: View {
    let title: String
    let description: String
    @ViewBuilder var buttonsView: () -> ButtonsView
    
    var body: some View {
        VStack {
            Spacer()
            ProjectEmptyStateView(title: title,
                                  description: description,
                                  buttonsView: buttonsView)
            Spacer()
        }
    }
}

struct ProjectEmptyStateView<ButtonsView: View>: View {
    let title: String
    let description: String
    @ViewBuilder var buttonsView: () -> ButtonsView
    
    var body: some View {
        VStack {
            Text(title)
            #if targetEnvironment(macCatalyst)
                .font(.largeTitle)
            #else
                .font(.title)
            #endif
                .padding(.vertical, 4)
            
            Text(description)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
            //                    .foregroundColor(.secondary) // Can't get to work on left sidebar
            
            VStack(spacing: 4) {
                buttonsView()
                    .buttonStyle(.borderless) // only way to get multiple images in one button to appear
                    .padding(8)
                    .background(.windowBackground)
                    .cornerRadius(8)
            }
        }
    }
}

struct KeyboardShortcutButtonLabel: View {
    let imageNames: [String]
    
    var body: some View {
        HStack(spacing: .zero) {
            ForEach(imageNames, id: \.self) { imageName in
                Image(systemName: imageName)
            }
            .imageScale(.small)
            .offset(y: 1)        // tweak vertical alignment
            .foregroundStyle(.secondary)
            .fixedSize()
        }
    }
}

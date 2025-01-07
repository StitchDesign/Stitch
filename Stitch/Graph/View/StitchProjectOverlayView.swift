//
//  StitchProjectOverlayView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/7/25.
//

import SwiftUI
import StitchSchemaKit

struct StitchProjectOverlayView: View {
    @Environment(\.appTheme) private var theme
    
    let document: StitchDocumentViewModel
    let store: StitchStore
    let showFullScreen: Bool
    let graphNamespace: Namespace.ID
    
    var graphUI: GraphUIState {
        self.document.graphUI
    }
    
    var showPreviewWindow: Bool {
        graphUI.showPreviewWindow
    }
    
    var body: some View {
        VStack {
            if graphUI.groupNodeFocused?.component != nil {
                ComponentNavBarView(graph: document.visibleGraph,
                                    store: store)
            }
            
            // Show debug mode tip view
            if document.isDebugMode {
                HStack {
                    Image(systemName: ProjectContextMenuModifer.debugModeIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30)
                        .foregroundStyle(theme.themeData.edgeColor)
                    
                    VStack(alignment: .leading) {
                        Text("Welcome to Debug Mode")
                            .font(.headline)
                        Text("Prototypes are paused to enable inspection of faults in your graph. This is useful for debugging hangs in your prototype. Root causes could include a high loop count in some node's input field.")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: 800)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding()
            }
            
            HStack(spacing: .zero) {
                Spacer()
                // Floating preview kept outside NavigationSplitView for animation purposes
                if !showFullScreen {
                    FloatingWindowView(
                        document: document,
                        deviceScreenSize: graphUI.frame.size,
                        showPreviewWindow: showPreviewWindow,
                        namespace: graphNamespace)
                }
            }
            // Hides prototype on debug mode
            // Opacity needed for some keybinding detection (i.e. spacebar drag)
            .opacity(document.isDebugMode ? 0 : 1)
            
            Spacer()
        }
        // Hack to disable the split view sidebar swipe
        .gesture(
            DragGesture()
                .onChanged { _ in }
        )
    }
}

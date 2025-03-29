//
//  StitchProjectOverlayView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/7/25.
//

import SwiftUI
import StitchSchemaKit

struct StitchProjectOverlayView: View {
    @Bindable var document: StitchDocumentViewModel
    let store: StitchStore
    let showFullScreen: Bool
    let graphNamespace: Namespace.ID
    
    var showPreviewWindow: Bool {
        document.showPreviewWindow
    }
    
    var body: some View {
        VStack {
            if document.groupNodeFocused?.component != nil {
                ComponentNavBarView(graph: document.visibleGraph,
                                    store: store)
            }
            
            HStack(spacing: .zero) {
                Spacer()
                // Floating preview kept outside NavigationSplitView for animation purposes
                if !showFullScreen {
                    FloatingWindowView(
                        document: document,
                        deviceScreenSize: document.frame.size,
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

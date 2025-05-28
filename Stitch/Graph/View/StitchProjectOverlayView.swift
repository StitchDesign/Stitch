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
        document.showPreviewWindow && !document.isScreenRecording
    }
    
    var finalXOffset: CGFloat {
        store.showsLayerInspector ? FloatingWindowView.xOffset - LayerInspectorView.LAYER_INSPECTOR_WIDTH : FloatingWindowView.xOffset
    }
    
    var body: some View {
        VStack {
            if document.groupNodeFocused?.component != nil {
                ComponentNavBarView(graph: document.visibleGraph,
                                    store: store)
            }
            
            overlayContent
            
            Spacer()
        }
        // Hack to disable the split view sidebar swipe
        .gesture(
            DragGesture()
                .onChanged { _ in }
        )
    }
    
    @ViewBuilder
    var overlayContent: some View {
        ZStack {
            // Show empty state view so long as debug mode isn't on and nodes are invisible
            if document.visibleGraph.patchNodes.isEmpty && !document.isDebugMode {
                PatchCanvasEmptyStateView(document: document)
            }
            
            HStack(spacing: .zero) {
                Spacer()
                // Floating preview kept outside NavigationSplitView for animation purposes
                if !showFullScreen {
                    FloatingWindowView(
                        store: store,
                        document: document,
                        deviceScreenSize: document.frame.size,
                        showPreviewWindow: showPreviewWindow,
                        namespace: graphNamespace)
                    .transition(.opacity)
                }
            }
            // Hides prototype on debug mode
            // Opacity needed for some keybinding detection (i.e. spacebar drag)
            .opacity(document.isDebugMode ? 0 : 1)
        }
        .offset(x: self.finalXOffset)
        .animation(.default, value: self.finalXOffset)
    }
}

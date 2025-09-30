//
//  ProjectNavigationView.swift
//  prototype
//
//  Created by Christian J Clampitt on 2/8/22.
//

import SwiftUI
import StitchSchemaKit

/// UI for interacting with a single project; iPad-only.
struct ProjectNavigationView: View {
    @Environment(StitchFileManager.self) var fileManager
    static private let iPadSidebarWidth: CGFloat = 300

    @Bindable var store: StitchStore
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let isFullScreen: Bool
    let routerNamespace: Namespace.ID
    let graphNamespace: Namespace.ID
    @Namespace private var topButtonsNamespace

    var previewWindowSizing: PreviewWindowSizing {
        self.document.previewWindowSizingObserver
    }
    
    @ViewBuilder
    var mainProjectView: some View {
#if !targetEnvironment(macCatalyst)
        // Use a ZStack so SwiftUI can animate insertion/removal with `.transition`
        ZStack {
            graphView
                .transition(.opacity)
                .id(ProjectTab.patch)   // ← make the views distinct
            
            ZStack {
                Stitch.APP_BACKGROUND_COLOR
                    .edgesIgnoringSafeArea(.all)
                
                ipadLayerView
                
                // Layer Inspector Fly‑out must sit above preview window
                flyout
            }
            .opacity(document.selectedTab == .layer ? 1 : 0)
            .transition(.opacity)
            .id(ProjectTab.layer)
        }
        .animation(.easeInOut(duration: 0.25), value: document.selectedTab)
        .animation(.easeInOut(duration: 0.25), value: document.selectedTab)
#else
        // iPhone / compact width
        ZStack {
            graphView
            
            // Layer Inspector Fly‑out must sit above preview window
            flyout
        }
        .transition(.opacity)
#endif
    }
    
    var graphView: some View {
        GraphBaseView(store: store, document: document)
            .overlay {
                StitchProjectOverlayView(document: document,
                                         store: store,
                                         showFullScreen: isFullScreen,
                                         graphNamespace: graphNamespace)
            }
    }
    
    @ViewBuilder
    var flyout: some View {
        OpenFlyoutView(document: document,
                       graph: document.visibleGraph)
    }

    var body: some View {
        mainProjectView
        #if !targetEnvironment(macCatalyst)
            .animation(.stitchAnimation, value: document.selectedTab)
        #endif
            .alert(item: $graph.migrationWarning) { warningMessage in
            Alert(title: Text("Document Migration Warning"),
                  message: Text(warningMessage.rawValue),
                  dismissButton: .default(.init("OK")) {
                // Encoding new document ensures this warning won't load again
                document.encodeProjectInBackground()
            })
        }
        .onChange(of: document.graphUpdaterId) {
            // log("ProjectNavigationView: .onChange(of: document.visibleGraph.graphUpdaterId)")
            document.visibleGraph.updateGraphData(document)
        }
        .onChange(of: document.isCameraEnabled) { _, isCameraEnabled in
            if !isCameraEnabled {
                // Tear down if no nodes enabled camera
                document.deactivateCamera()
                
                document.teardownSingleton(keyPath: \.cameraFeedManager)
            }
        }
    }
    
#if !targetEnvironment(macCatalyst)
    var ipadLayerView: some View {
        HStack(spacing: .zero) {
            StitchSidebarView(syncStatus: fileManager.syncStatus)
                .width(Self.iPadSidebarWidth)
            
            Spacer(minLength: 0)
            
            IPadPrototypePreview(store: store,
                                 namespace: graphNamespace)
            
            Spacer(minLength: 0)
            
            LayerInspectorView(graph: graph,
                               document: document)
            // Note: we actually want to respect the safe area on iPad OS 26 with LayerInspector
            .modifier(ConditionalIgnoreSafeAreaModifier())
            .width(Self.iPadSidebarWidth)
        }
    }
#endif
}

struct ConditionalIgnoreSafeAreaModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // On iOS 26+, don't ignore safe area to respect toolbar
            content
        } else {
            // On earlier versions, ignore safe area for the shimmer effect
            content.ignoresSafeArea()
        }
    }
}

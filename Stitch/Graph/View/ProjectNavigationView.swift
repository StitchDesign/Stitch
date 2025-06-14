//
//  ProjectNavigationView.swift
//  prototype
//
//  Created by Christian J Clampitt on 2/8/22.
//

import SwiftUI
import StitchSchemaKit

enum ProjectTab: String, Identifiable, CaseIterable {
    case patch = "Patches"
    case layer = "Layers"
}

extension ProjectTab {
    var id: String {
        self.rawValue
    }
    
    var systemIcon: String {
        switch self {
        case .patch:
            return "rectangle.3.group"
        case .layer:
            return "square.3.layers.3d.down.right"
        }
    }
}

/// UI for interacting with a single project; iPad-only.
struct ProjectNavigationView: View {
    @State private var selectedTab: ProjectTab = .patch

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
    
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    @ViewBuilder
    var mainProjectView: some View {
        if Self.isIPad {
            TabView(selection: self.$selectedTab) {
                Tab(ProjectTab.patch.rawValue,
                    systemImage: ProjectTab.patch.systemIcon,
                    value: ProjectTab.patch) {
                    graphView
                }
                Tab(ProjectTab.layer.rawValue,
                    systemImage: ProjectTab.layer.systemIcon,
                    value: ProjectTab.layer) {
                    FloatingWindowView(store: store,
                                       document: document,
                                       deviceScreenSize: document.frame.size,
                                       showPreviewWindow: document.showPreviewWindow && !document.isScreenRecording,
                                       namespace: graphNamespace)
                    .inspector(isPresented: $store.showsLayerInspector) {
                        LayerInspectorView(graph: graph,
                                           document: document)
                    }
                }
            }
        } else {
            graphView
            // Layer Inspector Flyout must sit above preview window
                .overlay {
                    flyout
                }
        }
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
}

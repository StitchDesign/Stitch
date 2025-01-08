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
    @Bindable var document: StitchDocumentViewModel
    let routerNamespace: Namespace.ID
    @Namespace private var topButtonsNamespace

    var previewWindowSizing: PreviewWindowSizing {
        self.document.previewWindowSizingObserver
    }

    // Tracks edge changes to reset cached data
    @MainActor var upstreamConnections: [NodeIOCoordinate?] {
        self.document.visibleGraph.nodes.values
            .flatMap { $0.getAllInputsObservers() }
            .map { $0.upstreamOutputCoordinate }
    }

    var body: some View {
        @Bindable var visibleGraph = document.visibleGraph
        
        GraphBaseView(document: document,
                      graphUI: document.graphUI)
        .alert(item: $visibleGraph.migrationWarning) { warningMessage in
            Alert(title: Text("Document Migration Warning"),
                  message: Text(warningMessage.rawValue),
                  dismissButton: .default(.init("OK")) {
                // Encoding new document ensures this warning won't load again
                document.encodeProjectInBackground()
            })
        }
        .onChange(of: document.visibleGraph.nodes.keys.count) {
            document.visibleGraph.updateGraphData()
        }
        .onChange(of: upstreamConnections) {
            document.visibleGraph.updateGraphData()
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

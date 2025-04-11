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
    @Bindable var store: StitchStore
    @Bindable var document: StitchDocumentViewModel
    let routerNamespace: Namespace.ID
    @Namespace private var topButtonsNamespace

    var previewWindowSizing: PreviewWindowSizing {
        self.document.previewWindowSizingObserver
    }

    var body: some View {
        @Bindable var visibleGraph = document.visibleGraph
        
        GraphBaseView(store: store,
                      document: document)
        .alert(item: $visibleGraph.migrationWarning) { warningMessage in
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

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
    let insertNodeMenuHiddenNodeId: NodeId?
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
        GraphBaseView(document: document,
                      graphUI: document.graphUI,
                      insertNodeMenuHiddenNodeId: insertNodeMenuHiddenNodeId)
        .onChange(of: document.visibleGraph.nodes.keys.count) {
            document.visibleGraph.updateGraphData()
        }
        .onChange(of: upstreamConnections) {
            document.visibleGraph.updateGraphData()
        }
    }
}

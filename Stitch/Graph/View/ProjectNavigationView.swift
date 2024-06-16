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
    @Bindable var graph: GraphState

    let insertNodeMenuHiddenNodeId: NodeId?

    let routerNamespace: Namespace.ID
    @ObservedObject var previewWindowSizing: PreviewWindowSizing

    @Namespace private var topButtonsNamespace

    var body: some View {
        graphView
    }

    var debugView: Text {
        Text("Graph UI Here")
    }
    
    // Tracks edge changes to reset cached data
    var upstreamConnections: [NodeIOCoordinate?] {
        self.graph.nodes.values
            .flatMap { $0.getRowObservers(.input) }
            .map { $0.upstreamOutputCoordinate }
    }

    @ViewBuilder
    var graphView: some View {
        GraphBaseView(graph: graph,
                      graphUI: graph.graphUI,
                      insertNodeMenuHiddenNodeId: insertNodeMenuHiddenNodeId)
        // TODO: what is the best way / place `updateGraphData` (i.e. the node row observers)? Seems okay perf-wise? ... Specifically for input- or output-port colors.
        .onChange(of: graph.nodes.keys.count) {
            graph.updateGraphData()
        }
        .onChange(of: upstreamConnections) {
            graph.updateGraphData()
        }
    }
}

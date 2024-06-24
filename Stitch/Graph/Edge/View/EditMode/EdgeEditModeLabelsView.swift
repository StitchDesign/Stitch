//
//  EdgeEditModeLabelsView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/26/23.
//

import SwiftUI
import StitchSchemaKit

// TODO: why does this render so many times when a single node is added?
struct EdgeEditModeLabelsView: View {

    // TODO: look at the perf implications here; ideally this view should be rendered only when output is hovered
    // Be careful about animations etc.
    var graph: GraphState

    let portId: Int

    @MainActor
    var graphUI: GraphUIState {
        graph.graphUI
    }

    var label: EdgeEditingModeInputLabel? {
        portId.toEdgeEditingModeInputLabel
    }

    @MainActor
    var isPressed: Bool {
        label.map { graphUI.keypressState.characters.contains($0.display.toCharacter) }
            ?? false
    }

    var body: some View {
        if let label = label {
            EdgeEditModeInputLabelView(label: label,
                                       isPressed: isPressed)
        } else {
            EmptyView()
        }
    }

}

//
//  EdgeEditModeLabelsView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/26/23.
//

import SwiftUI
import StitchSchemaKit

struct EdgeInputLabelsView: View {
    let inputs: [InputNodeRowViewModel]
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graphUI: GraphUIState

    var body: some View {
        let showLabels = document.graphUI.edgeEditingState?.labelsShown ?? false
        
        if let nearbyCanvasItem: CanvasItemId = document.graphUI.edgeEditingState?.nearbyCanvasItem {
            ForEach(inputs) { inputRowViewModel in
                
                // Doesn't seem to be needed? Checking the canvasItemDelegate seems to work well
                // visibleNodeId property checks for group splitter inputs
                // let isInputForNearbyNode = inputRowViewModel.visibleNodeIds.contains(nearbyCanvasItem)
                
                let isInputOnNearbyCanvasItem = inputRowViewModel.canvasItemDelegate?.id == nearbyCanvasItem
                let isVisible = isInputOnNearbyCanvasItem && showLabels
                
                EdgeEditModeLabelsView(document: document,
                                       portId: inputRowViewModel.id.portId)
                .position(inputRowViewModel.anchorPoint ?? .zero)
                .opacity(isVisible ? 1 : 0)
                .animation(.linear(duration: .EDGE_EDIT_MODE_NODE_UI_ELEMENT_ANIMATION_LENGTH),
                           value: isVisible)
            }
        } else {
            EmptyView()
        }
    }
}

// TODO: why does this render so many times when a single node is added?
struct EdgeEditModeLabelsView: View {

    // TODO: look at the perf implications here; ideally this view should be rendered only when output is hovered
    // Be careful about animations etc.
    var document: StitchDocumentViewModel

    let portId: Int

    var label: EdgeEditingModeInputLabel? {
        portId.toEdgeEditingModeInputLabel
    }

    @MainActor
    var isPressed: Bool {
        label.map { document.keypressState.characters.contains($0.display.toCharacter) }
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

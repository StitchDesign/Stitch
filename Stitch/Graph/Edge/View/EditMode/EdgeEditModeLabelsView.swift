//
//  EdgeEditModeLabelsView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/26/23.
//

import SwiftUI
import StitchSchemaKit

struct EdgeInputLabelsView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let edgeEditingState: EdgeEditingState

    var nearbyCanvas: CanvasItemViewModel? {
        graph.getCanvasItem(edgeEditingState.nearbyCanvasItem)
    }
    
    func inputsEnabled(_ nodeId: NodeId) -> Bool {
        if let patch = graph.getPatchNode(id: nodeId)?.patch,
           patch.inputsDisabled {
            return false
        }
        return true
    }
    
    var body: some View {
        let showLabels = edgeEditingState.labelsShown
            
        if let nearbyCanvas = nearbyCanvas,
           self.inputsEnabled(nearbyCanvas.id.nodeId) {
            
            // if this is a patch node with inputs disable, ignore do not show labels
            ForEach(nearbyCanvas.inputPortUIViewModels) { portUIViewModel in
                EdgeEditModeLabelsView(
                    keyPressStateCharacters: document.keypressState.characters,
                    portId: portUIViewModel.portIdForAnchorPoint)
                .position(portUIViewModel.anchorPoint ?? .zero)
                .opacity(showLabels ? 1 : 0)
                .animation(.linear(duration: .EDGE_EDIT_MODE_NODE_UI_ELEMENT_ANIMATION_LENGTH),
                           value: showLabels)
            }
        } else {
            EmptyView()
        }
    }
}

// TODO: why does this render so many times when a single node is added?
struct EdgeEditModeLabelsView: View {
    let keyPressStateCharacters: Set<Character>

    let portId: Int

    var label: EdgeEditingModeInputLabel? {
        portId.toEdgeEditingModeInputLabel
    }

    @MainActor
    var isPressed: Bool {
        label.map { keyPressStateCharacters.contains($0.display.toCharacter) }
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

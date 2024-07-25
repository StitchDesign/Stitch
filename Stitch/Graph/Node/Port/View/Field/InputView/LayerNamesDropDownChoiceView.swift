//
//  LayerNamesDropDownChoiceView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/31/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import OrderedCollections

// Note:
struct LayerNamesDropDownChoiceView: View {
    @State private var selection: NodeViewModel = NodeViewModel.nilChoice

    @Bindable var graph: GraphState

    let id: InputCoordinate
    let value: PortValue

    @MainActor
    func onSet(_ node: NodeViewModel) {
        dispatch(InteractionPickerOptionSelected(
                    interactionPatchNodeInput: self.id,
                    layerNodeIdSelection: node.id.asLayerNodeId))
    }

    @MainActor
    var layerOptions: NodeViewModels {
        var options: NodeViewModels = [NodeViewModel.nilChoice]
        options += self.graph.orderedSidebarLayers.getIds()
            .compactMap { self.graph.getNodeViewModel($0) }
        return options
    }

    @MainActor
    var selectionTitle: String {
        #if DEV_DEBUG
        self.selection.displayTitle + " " + self.selection.id.description.dropLast(24)
        #else
        self.selection.displayTitle
        #endif
    }

    var body: some View {
        
        Menu {
            ForEach(self.layerOptions) { node in
                @Bindable var node = node
                StitchButton {
                    self.onSet(node)
                } label: {
#if DEV_DEBUG
                    StitchTextView(string: "\(node.displayTitle) \(node.id.description.dropLast(24))")
#else
                    StitchTextView(string: node.displayTitle)
#endif
                }
            }
        } label: {
            StitchTextView(string: selectionTitle)
        }
#if targetEnvironment(macCatalyst)
        .buttonStyle(.plain)
#endif
        
        
        
        .onChange(of: self.selection.id) {
            self.onSet(self.selection)
        }
        .onChange(of: self.value, initial: true) {
            guard let persistedInteractionId = value.getInteractionId,
                  let node = self.graph.getNodeViewModel(persistedInteractionId.id) else {
                self.selection = NodeViewModel.nilChoice
                return
            }
            
            self.selection = node
        }
    }
}

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

// TODO: can this be combined with regular Dropdown view?
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
        StitchMenu(id: id.nodeId,
                   selection: selectionTitle,
                   contentCatalyst: {
                    // TODO: replace with the string-based Picker of DropdownChoiceView + StitchPickerView ? Any reason why you can't use a SwiftUI Picker here? Something about key presses?
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
                   }, contentIPad: {
                       // TODO: revisit this; may want to use the string-based Picker of DropdownChoiceView + StitchPickerView; until we do so, or update the below code, LayerNamesDropDown on iPad will not properly show the picker
                       // see https://github.com/vpl-codesign/stitch/issues/5294
                       
//                       Picker("", selection: self.$selection) {
//                           ForEach(self.layerOptions) { node in
//                               @Bindable var node = node
//                               StitchTextView(string: node.displayTitle)
//                               // MARK: tag necessaray to get this to work
//                               //                                .tag(node)
//                                   .tag(node.id)
//                           }
//                       } // Picker
                       
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
                       
                   }, // contentIPad:
                   
                   // overal label for the view
                   label: {
                       StitchTextView(string: selectionTitle)
                   }
        )
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

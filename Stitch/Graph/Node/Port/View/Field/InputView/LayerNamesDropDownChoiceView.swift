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


struct LayerDropdownChoice: Equatable, Identifiable, Codable, Hashable {
    let id: String // uuid for layers; but non-uuid string for Root or Parent PinTo's
    let name: String
}

typealias LayerDropdownChoices = [LayerDropdownChoice]

extension LayerDropdownChoice {
    
    var asPinToId: PinToId {
        if self.id == LayerDropdownChoice.RootLayerDropDownChoice.id {
            return .root
        } else if self.id == LayerDropdownChoice.ParentLayerDropDownChoice.id {
            return .parent
        } else {
            guard let selectedLayerId: LayerNodeId = UUID(uuidString: self.id)?.asLayerNodeId else {
                fatalErrorIfDebug()
                return .root
            }
            return .layer(selectedLayerId)
        }
    }

    // Only for non-PinTo
    static let NilLayerDropDownChoice: Self = .init(id: "NIL_LAYER_DROPDOWN_CHOICE_ID",
                                                    name: "None")
    
    // Only for PinTo
    static let RootLayerDropDownChoice: Self = .init(id: "ROOT_LAYER_DROPDOWN_CHOICE_ID",
                                                     name: "Root")
    static let ParentLayerDropDownChoice: Self = .init(id: "PARENT_LAYER_DROPDOWN_CHOICE_ID",
                                                       name: "Parent")
}

extension NodeViewModel {
    var asLayerDropdownChoice: LayerDropdownChoice {
        .init(id: self.id.uuidString,
              name: self.getDisplayTitle())
    }
}

extension GraphState {
    func layerDropdownChoices(isForPinTo: Bool) -> LayerDropdownChoices {
        
        let initialChoices: LayerDropdownChoices = isForPinTo ? [.RootLayerDropDownChoice, .ParentLayerDropDownChoice] : [.NilLayerDropDownChoice]
        
        return initialChoices + self.orderedSidebarLayers.getIds().compactMap {
            self.getNodeViewModel($0)?.asLayerDropdownChoice
        }
    }
}

// Note:
struct LayerNamesDropDownChoiceView: View {
    @State private var selection: LayerDropdownChoice = .NilLayerDropDownChoice

    @Bindable var graph: GraphState

    let id: InputCoordinate
    let value: PortValue
    
    var isForPinTo: Bool = false

    @MainActor
    func onSet(_ choice: LayerDropdownChoice) {
        
        let selectedLayerId: LayerNodeId? = UUID(uuidString: choice.id)?.asLayerNodeId
        
        if isForPinTo {
            // TODO: add PortValue.pinTo case
            dispatch(PickerOptionSelected(input: self.id,
                                          choice: .pinTo(choice.asPinToId)))
        } else {
            dispatch(InteractionPickerOptionSelected(
                        interactionPatchNodeInput: self.id,
                        layerNodeIdSelection: selectedLayerId))
        }
    }

    var choices: LayerDropdownChoices
    
    @MainActor
    var selectionTitle: String {
        #if DEV_DEBUG
        self.selection.name + " " + self.selection.id.description.dropLast(24)
        #else
        self.selection.name
        #endif
    }

    var body: some View {
        
        Menu {
            ForEach(self.choices) { choice in
                StitchButton {
                    self.onSet(choice)
                } label: {
#if DEV_DEBUG
                    StitchTextView(string: "\(choice.name) \(choice.id.description.dropLast(24))")
#else
                    StitchTextView(string: choice.name)
#endif
                }
            }
        } label: {
            StitchTextView(string: selectionTitle)
        }
#if targetEnvironment(macCatalyst)
        .buttonStyle(.plain)
#endif
        // Adjust for whether this dropdown is used for regular layers or pinTo layers
        .onAppear {
            if isForPinTo {
                self.selection = .RootLayerDropDownChoice
            } else {
                self.selection = .NilLayerDropDownChoice
            }
        }
        
        // Not needed?
        .onChange(of: self.selection.id) {
            self.onSet(self.selection)
        }
        .onChange(of: self.choices) { oldValue, newValue in
            if let currentSelection = self.choices.first(where: { choice in
                choice.id == self.selection.id
            }) {
                self.selection = currentSelection
            }
        }
        
        // What is this really doing? Why are we passing in the PortValue ?
        // Ah, the idea is, wge
        .onChange(of: self.value, initial: true) { oldValue, newValue in
            
            if let pinToId = newValue.getPinToId {
                switch pinToId {
                case .root:
                    self.selection = .RootLayerDropDownChoice
                case .parent:
                    self.selection = .ParentLayerDropDownChoice
                case .layer(let x):
                    self.selection = self.graph.getNode(x.id)?.asLayerDropdownChoice ?? .NilLayerDropDownChoice
                }
            } else if let interactionId = newValue.getInteractionId {
                if let node = self.graph.getNodeViewModel(interactionId.id)?.asLayerDropdownChoice {
                    self.selection = node
                } else {
                    // i.e. what happens if the passed-in PortValue is for a node that no longer exists?
                    // Really, we should fix that at the PortValue-level; just changing it at the UI-level here could be confusing...
                    self.selection = .NilLayerDropDownChoice
                }
            } else {
                self.selection = .NilLayerDropDownChoice
            }
        }
    }
}

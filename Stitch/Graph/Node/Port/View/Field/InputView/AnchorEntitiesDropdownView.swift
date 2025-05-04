//
//  AnchorEntitiesDropdownView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/8/24.
//

import SwiftUI
import StitchSchemaKit

struct AnchorDropdownChoice: Identifiable, Equatable {
    let id: UUID
    let name: String
}

extension AnchorDropdownChoice {
    static let noneDisplayName = "None"
    
    static let none: Self = .init(id: .init(), name: Self.noneDisplayName)
}

struct AnchorEntitiesDropdownView: View {
    @State private var selection: AnchorDropdownChoice = .none
    let rowObserver: InputNodeRowObserver
    let graph: GraphState
    let value: PortValue
    let isFieldInsideLayerInspector: Bool
    let activeIndex: ActiveIndex
    
    var choices: [AnchorDropdownChoice] {
        let initialChoices: [AnchorDropdownChoice] = [.none]
        
        return graph.nodes.values.reduce(into: initialChoices) { result, node in
            if node.kind.getPatch == .arAnchor {
                result.append(.init(id: node.id,
                                    name: node.getDisplayTitle()))
            }
        }
    }
    
    @MainActor
    func onSet(_ choice: AnchorDropdownChoice) {
        let selectedId: UUID? = choice.id == AnchorDropdownChoice.none.id ? nil : choice.id
        
        graph.handleInputEditCommitted(input: rowObserver,
                                       value: .anchorEntity(selectedId),
                                       activeIndex: activeIndex,
                                       isFieldInsideLayerInspector: false)
        graph.encodeProjectInBackground()
    }
    
    var body: some View {
        Menu {
            ForEach(self.choices) { choice in
                StitchButton {
                    self.onSet(choice)
                } label: {
                    StitchTextView(string: choice.name)
                }
            }
        } label: {
            StitchTextView(string: self.selection.name)
        }
#if targetEnvironment(macCatalyst)
        .buttonStyle(.plain)
#endif
        .onChange(of: self.choices) { oldValue, newValue in
            let newSelection = self.choices.first { $0.id == self.selection.id } ?? .none
            
            // Changes if anchor is deleted
            if self.selection != newSelection {
                self.onSet(newSelection)
            }
        }
        
        // What is this really doing? Why are we passing in the PortValue ?
        // Ah, the idea is, wge
        .onChange(of: self.value, initial: true) { oldValue, newValue in
            guard let anchorEntityNodeId = newValue.anchorEntity,
                  let node = self.graph.getNode(anchorEntityNodeId) else {
                self.selection = .none
                return
            }
            
            self.selection = .init(id: anchorEntityNodeId,
                                   name: node.getDisplayTitle())
        }
    }
}

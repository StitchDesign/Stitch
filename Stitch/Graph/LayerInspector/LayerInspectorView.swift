//
//  LayerInspectorView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/16/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LayerInspectorView: View {
    @State private var debugLocation: String = "none"
    
    @State private var isLayoutExpanded = true
    @State private var isSomeSectionExpanded = true
    @State private var isAnotherSectionExpanded = true
    
    let graph: GraphState
    
    @MainActor var selectedLayerNode: NodeViewModel? {
        for nodeId in self.graph.selectedNodeIds {
            if let node = graph.getNodeViewModel(nodeId),
                node.layerNode != nil {
                return node
            }
        }
        return nil
    }
    
    var body: some View {
        if let node = selectedLayerNode,
           let layerNode = node.layerNode {
            selectedLayerView(node, layerNode)
        } else {
            EmptyView()
        }
    }
    
    @MainActor func selectedLayerView(_ node: NodeViewModel,
                                      _ layerNode: LayerNodeViewModel) -> some View {
        List {
            // Sections will split up the chunks of inputs
            Section(isExpanded: $isLayoutExpanded) {
                // MARK: manually iterate through every possible layer input.
                // Filter using contains, this will be more efficient with future changes
                ForEach(Self.orderedLayoutInputs) { input in
                    portView(for: input,
                             node: node,
                             layerNode: layerNode)
                }
            } header: {
                StitchTextView(string: "Layout")
            }
            
            Section(isExpanded: $isSomeSectionExpanded) {
                ForEach(Self.anotherSectionInputs) { input in
                    portView(for: input,
                             node: node,
                             layerNode: layerNode)
                }
            } header: {
                StitchTextView(string: "Another Section")
            }
            
            Section(isExpanded: $isAnotherSectionExpanded) {
                ForEach(Self.andAnotherSectionInputs) { input in
                    portView(for: input,
                             node: node,
                             layerNode: layerNode)
                }
            } header: {
                StitchTextView(string: "Another Section")
            }
        }
    }
    
    @MainActor @ViewBuilder func portView(for layerInputType: LayerInputType,
                             node: NodeViewModel,
                             layerNode: LayerNodeViewModel) -> some View {
        let definition = layerNode.layer.layerGraphNode
        let inputsList = definition.inputDefinitions
        let rowObserver = layerNode[keyPath: layerInputType.layerNodeKeyPath]
        
        // See if layer node uses this input
        if inputsList.contains(layerInputType),
           let portViewType = rowObserver.portViewType {
            NodeInputOutputView(graph: graph,
                                       node: node,
                                       rowData: rowObserver,
                                       coordinateType: portViewType,
                                       nodeKind: .layer(layerNode.layer),
                                       isNodeSelected: false,
                                       adjustmentBarSessionId: graph.graphUI.adjustmentBarSessionId)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    let graph = GraphState(from: .init(), store: nil)
    let nodeTest = TextLayerNode.createViewModel(position: .zero,
                                                 zIndex: .zero,
                                                 activeIndex: .init(.zero),
                                                 graphDelegate: graph)
    nodeTest.isSelected = true
    
    graph.nodes.updateValue(nodeTest, forKey: nodeTest.id)
    
    return LayerInspectorView(graph: graph)
}

extension LayerInspectorView {
    // TODO: fill these out
    static let orderedLayoutInputs: [LayerInputType] = [
        .position,
        .size
    ]
    
    // MARK: each one of these corresponds to a section
    static let anotherSectionInputs: [LayerInputType] = [
        .opacity
    ]
    
    static let andAnotherSectionInputs: [LayerInputType] = [
        .color
    ]
}

extension LayerInputType: Identifiable {
    public var id: Int {
        self.hashValue
    }
}

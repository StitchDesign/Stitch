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
    
    // TODO: better?: allow user to resize inspector; and we read the width via GeometryReader
    static let LAYER_INSPECTOR_WIDTH = 360.0
    
    @State private var debugLocation: String = "none"
    
    @State private var isLayoutExpanded = true
    @State private var isSomeSectionExpanded = true
    @State private var isAnotherSectionExpanded = true
    
//    let graph: GraphState // should be Bindable?
    @Bindable var graph: GraphState // should be Bindable?
    
    // TODO: property sidebar changes when multiple sidebar layers are selected
    @MainActor
    var selectedLayerNode: NodeViewModel? {
        guard let firstSidebarLayerId = graph.orderedSidebarLayers.first?.id else {
            log("LayerInspectorView: No sidebar layers")
            return nil
        }
        
        guard let node = graph.getNodeViewModel(firstSidebarLayerId),
              node.layerNode.isDefined else {
            log("LayerInspectorView: No node for sidebar layer id \(firstSidebarLayerId)")
            return nil
        }
        
        return node
    }
    
    var body: some View {
        if let node = selectedLayerNode,
           let layerNode = node.layerNode {
            selectedLayerView(node, layerNode)
        } else {
            // Empty List, so have same background
            List { }
        }
    }
    
    @MainActor
    func selectedLayerView(_ node: NodeViewModel,
                           _ layerNode: LayerNodeViewModel) -> some View {
        List {
            
            // TODO: remove?
            Text(node.displayTitle).font(.title2)
            
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
                    .onTapGesture {
                        self.isLayoutExpanded.toggle()
                    }
            }
                        
            Section(isExpanded: $isSomeSectionExpanded) {
                ForEach(Self.anotherSectionInputs) { input in
                    portView(for: input,
                             node: node,
                             layerNode: layerNode)
                }
            } header: {
                StitchTextView(string: "Another Section")
                    .onTapGesture {
                        self.isSomeSectionExpanded.toggle()
                    }
            }
            
            Section(isExpanded: $isAnotherSectionExpanded) {
//                ForEach(Self.andAnotherSectionInputs) { input in
//                    portView(for: input,
//                             node: node,
//                             layerNode: layerNode)
//                }
                
                // demo'ing using menu / dropdown
                DropDownChoiceView(id: .fakeInputCoordinate,
                                   choiceDisplay: StitchOrientation.choices.first!.display,
                                   choices: StitchOrientation.choices)
                
            } header: {
                StitchTextView(string: "Another Section")
                    .onTapGesture {
                        self.isAnotherSectionExpanded.toggle()
                    }
            }
        }
    }
    
    @MainActor @ViewBuilder
    func portView(for layerInputType: LayerInputType,
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

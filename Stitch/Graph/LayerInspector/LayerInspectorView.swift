//
//  LayerInspectorView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/16/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension LayerInputType: Identifiable {
    // https://stackoverflow.com/questions/71358712/swiftui-is-it-ok-to-use-hashvalue-in-identifiable
    // Actually, using hashValue for id is a bad idea?
    public var id: Int {
        self.hashValue
    }
}

// MARK: Right-hand sidebar i.e. "Property sidebar"

struct LayerInspectorView: View {
    
    // TODO: better?: allow user to resize inspector; and we read the width via GeometryReader
    static let LAYER_INSPECTOR_WIDTH = 360.0
        
    @Bindable var graph: GraphState // should be Bindable?
    
    // TODO: property sidebar changes when multiple sidebar layers are selected
    @MainActor
    var selectedLayerNode: NodeViewModel? {
        
        guard !graph.orderedSidebarLayers.isEmpty else {
            return nil
        }
     
        // Take the last (most-recently) tapped sidebar layer; or the first non-selected layer.
        let inspectedLayer = graph.layerFocusedInPropertyInspector
        guard let inspectedLayerId = inspectedLayer,
              let node = graph.getNodeViewModel(inspectedLayerId),
              node.layerNode.isDefined else {
            log("LayerInspectorView: No node for sidebar layer \(inspectedLayer)")
            return nil
        }
        
        return node
    }
    
    var body: some View {
        if let node = selectedLayerNode,
           let layerNode = node.layerNode {
            
            UIKitWrapper(ignoresKeyCommands: false,
                         name: "LayerInspectorView") {
                selectedLayerView(node, layerNode)
            }

            // TODO: need UIKitWrapper to detect keypresses; alternatively, place UIKitWrapper on the sections themselves?
            // Takes care of the mysterious white top padding UIKitWrapper introduces
            #if targetEnvironment(macCatalyst)
                         .padding(.top, -40)
            #else
                         .padding(.top, -60)
                         .padding(.bottom, -20)
            #endif
            
                         .onAppear {
#if DEV_DEBUG
                             let listedLayers = Self.required
                                 .union(Self.common)
                                 .union(Self.groupLayer)
                                 .union(Self.unknown)
                                 .union(Self.text)
                                 .union(Self.stroke)
                                 .union(Self.rotation)
                                 .union(Self.shadow)
                                 .union(Self.effects)
                             
                             let allLayers = LayerInputType.allCases.toSet
                             let diff = allLayers.subtracting(listedLayers)
                             log("diff: \(diff)")
                             assert(diff.count == 0)
#endif
                         }
        } else {
            // Empty List, so have same background
            List { }
        }
    }
        
    @MainActor @ViewBuilder
    func selectedLayerView(_ node: NodeViewModel,
                           _ layerNode: LayerNodeViewModel) -> some View {
        
        // TODO: perf implications?
        let section = { (title: String, layers: LayerInputTypeSet) -> LayerInspectorInputsSectionView in
            LayerInspectorInputsSectionView(
                title: title,
                layerInputs: layers,
                node: node,
                layerNode: layerNode,
                graph: graph)
        }
        
        List {
            // TODO: remove?
            Text(node.displayTitle).font(.title2)
            
            section("Required", Self.required)
            section("Common", Self.common)
            
            if layerNode.layer.supportsGroupInputs {
                section("Group", Self.groupLayer)
            }
            
            if layerNode.layer.supportsUnknownInputs {
                section("Enabled", Self.unknown)
            }
            
            if layerNode.layer.supportsTypographyInputs {
                section("Typography", Self.text)
            }
            
            if layerNode.layer.supportsStrokeInputs {
                section("Stroke", Self.stroke)
            }
            
            if layerNode.layer.supportsRotationInputs {
                section("Rotation", Self.rotation)
            }
            
            if layerNode.layer.supportsShadowInputs {
                section("Shadow", Self.shadow)
            }
            
            if layerNode.layer.supportsLayerEffectInputs {
                section("Layer Effects", Self.effects)
            }
            
            LayerInspectorOutputsSectionView(node: node, 
                                             layerNode: layerNode,
                                             graph: graph)
        }
    }
}

struct LayerInspectorInputsSectionView: View {
    
    let title: String
    let layerInputs: LayerInputTypeSet
    
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    @State private var expanded = true
    
    var body: some View {
        let inputsList = layerNode.layer.layerGraphNode.inputDefinitions
        
        Section(isExpanded: $expanded) {
            ForEach(layerInputs) { layerInput in
                if inputsList.contains(layerInput) {
                    LayerInspectorPortView(
                        layerProperty: .layerInput(layerInput),
                        rowObserver: layerNode[keyPath: layerInput.layerNodeKeyPath],
                        node: node,
                        layerNode: layerNode,
                        graph: graph)
                }
            }
            .transition(.slideInAndOut(edge: .top))
        } header: {
            HStack  {
                StitchTextView(string: title)
                Spacer()
                let rotationZ: CGFloat = expanded ? 90 : 0
                Image(systemName: CHEVRON_GROUP_TOGGLE_ICON)
                    .rotation3DEffect(Angle(degrees: rotationZ),
                                      axis: (x: 0, y: 0, z: rotationZ))
                    .animation(.linear(duration: 0.2), value: rotationZ)
            }
            .padding(4)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    self.expanded.toggle()
                    layerInputs.forEach {
                        graph.graphUI.propertySidebar.selectedProperties.remove(.layerInput($0))
                    }
                }
            }
        }
    }
}

struct LayerInspectorOutputsSectionView: View {
    
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
        
    var body: some View {
        
        let outputs = node.outputRowObservers()
        
        if outputs.isEmpty {
            EmptyView()
        } else {
            Section(isExpanded: .constant(true)) {
                ForEach(outputs) { output in
                    if let portId = output.id.portId {
                        LayerInspectorPortView(
                            layerProperty: .layerOutput(.init(portId: portId,
                                                              nodeId: output.id.nodeId)),
                            rowObserver: output,
                            node: node,
                            layerNode: layerNode,
                            graph: graph)
                    } else {
                        Color.clear.onAppear {
                            fatalErrorIfDebug("Did not have portId for layer node output")
                        }
                    }
                }
            } header: {
                StitchTextView(string: "Outputs")
                    .padding(4)
            }
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


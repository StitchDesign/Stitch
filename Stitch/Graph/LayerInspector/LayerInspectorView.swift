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

#if targetEnvironment(macCatalyst)
let INSPECTOR_LIST_TOP_PADDING = -40.0
#else
let INSPECTOR_LIST_TOP_PADDING = -60.0
#endif

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
                         .padding(.top, INSPECTOR_LIST_TOP_PADDING)
            #else
                         .padding(.top, INSPECTOR_LIST_TOP_PADDING)
                         .padding(.bottom, -20)
            #endif
            
//                         .onAppear {
//#if DEV_DEBUG
//                             let listedLayers = Self.required
//                                 .union(Self.common)
//                                 .union(Self.groupLayer)
//                                 .union(Self.unknown)
//                                 .union(Self.text)
//                                 .union(Self.stroke)
//                                 .union(Self.rotation)
//                                 .union(Self.shadow)
//                                 .union(Self.effects)
//                             
//                             let allLayers = LayerInputType.allCases.toSet
//                             let diff = allLayers.subtracting(listedLayers)
//                             log("diff: \(diff)")
//                             assert(diff.count == 0)
//#endif
//                         }
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
        
        VStack(alignment: .leading) {
            
            //            // TODO: remove? make editable TextField for renaming etc.?
            //            // TODO: want something that
            //            Text(node.displayTitle).font(.title2)
            //                            .padding()
            //#if targetEnvironment(macCatalyst)
            //                .padding(.top, 12)
            //#else
            //                .padding(.top, 12)
            //#endif
            ////                         .background(.clear)
            //
            
            List {
                // TODO: remove?
                Text(node.displayTitle).font(.title2)
                
                section("Required", Self.required)
                
                section("Sizing", Self.sizing)
                
                section("Positioning", Self.positioning)
                
                section("Common", Self.common)
                
                if layerNode.layer.supportsPinningInputs {
                    section("Pinning", LayerInputTypeSet.pinning)
                }
                
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
//                    section("Shadow", Self.shadow)
                    
                    // will this row be selectable ?
                    StitchTextView(string: "Shadow")
                        .padding(4)
                        .background {
                            // Extending the hit area of the NodeInputOutputView view
                            Color.white.opacity(0.001)
                                .padding(-12)
                                .padding(.trailing, -LayerInspectorView.LAYER_INSPECTOR_WIDTH)
                        }
                    
                        .listRowBackground(Color.clear)
                    
                        .modifier(LayerPropertyRowOriginReader(
                            graph: graph,
                            layerInput: SHADOW_FLYOUT_LAYER_INPUT_PROXY))
                        .onTapGesture {
                            dispatch(FlyoutToggled(flyoutInput: SHADOW_FLYOUT_LAYER_INPUT_PROXY,
                                                   flyoutNodeId: node.id))
                        }
                }
                
                if layerNode.layer.supportsLayerEffectInputs {
                    section("Layer Effects", Self.effects)
                }
                
                LayerInspectorOutputsSectionView(node: node,
                                                 layerNode: layerNode,
                                                 graph: graph)
            }
            
        } // VStack
    }
}

struct LayerPropertyRowOriginReader: ViewModifier {
    
    @Bindable var graph: GraphState
    let layerInput: LayerInputType
    
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                Color.clear.onChange(of: geometry.frame(in: .global),
                                     initial: true) { oldValue, newValue in

                    // log("LayerInspectorInputs: read LayerInputType: \(layerInput): origin \(newValue.origin)")
                    
                    // Guide for where to place the flyout;
                    // we read the origin even if this row doesn't support flyout.
                    graph.graphUI.propertySidebar.propertyRowOrigins
                        .updateValue(newValue.origin, forKey: layerInput)
                }
            } // GeometryReader
        } // .background
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
                
                let inputListContainsInput = inputsList.contains(layerInput)
                
                let layerInputData = layerNode[keyPath: layerInput.layerNodeKeyPath]
                let rowObserver = layerInputData.rowObserver
                
                let allFieldsBlockedOut = layerInputData.inspectorRowViewModel .fieldValueTypes.first?.fieldObservers.allSatisfy(\.isBlockedOut) ?? false
                
                if inputListContainsInput && !allFieldsBlockedOut {
                    LayerInspectorInputPortView(
                        layerInput: layerInput,
                        rowViewModel: layerInputData.inspectorRowViewModel,
                        rowObserver: rowObserver,
                        node: node,
                        layerNode: layerNode,
                        graph: graph)
                    .modifier(LayerPropertyRowOriginReader(graph: graph,
                                                           layerInput: layerInput))
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
                    layerInputs.forEach { layerInput in
                        if case let .layerInput(x) = graph.graphUI.propertySidebar.selectedProperty,
                           x == layerInput {
                            graph.graphUI.propertySidebar.selectedProperty = nil
                        }
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
        
        let outputs = layerNode.outputPorts
        
        if outputs.isEmpty {
            EmptyView()
        } else {
            Section(isExpanded: .constant(true)) {
                ForEach(outputs) { output in
                    if let portId = output.rowObserver.id.portId {
                        LayerInspectorOutputPortView(
                            outputPortId: portId,
                            rowViewModel: output.inspectorRowViewModel,
                            rowObserver: output.rowObserver,
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


//#Preview {
//    let graph = GraphState(from: .init(), store: nil)
//    let nodeTest = TextLayerNode.createViewModel(position: .zero,
//                                                 zIndex: .zero,
//                                                 activeIndex: .init(.zero),
//                                                 graphDelegate: graph)
//    nodeTest.isSelected = true
//    
//    graph.nodes.updateValue(nodeTest, forKey: nodeTest.id)
//    
//    return LayerInspectorView(graph: graph)
//}


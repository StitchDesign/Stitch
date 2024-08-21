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
    public var id: Self {
        self
    }
}

extension LayerInputPort: Identifiable {
    public var id: Self {
        self
    }
}

#if targetEnvironment(macCatalyst)
let INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET = 2.0
#else
let INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET = 4.0
#endif


#if targetEnvironment(macCatalyst)
let INSPECTOR_LIST_TOP_PADDING = -40.0
let FLYOUT_SAFE_AREA_BOTTOM_PADDING = 16.0
#else
let INSPECTOR_LIST_TOP_PADDING = -60.0
let FLYOUT_SAFE_AREA_BOTTOM_PADDING = 24.0
#endif

// MARK: Right-hand sidebar i.e. "Property sidebar"

struct LayerInspectorView: View {
    
    // TODO: better?: allow user to resize inspector; and we read the width via GeometryReader
    static let LAYER_INSPECTOR_WIDTH = 360.0
    
    @Bindable var graph: GraphState // should be Bindable?
    
//    // TODO: property sidebar changes when multiple sidebar layers are selected
//    @MainActor
//    var selectedLayerNode: NodeViewModel? {
//        
//        guard !graph.orderedSidebarLayers.isEmpty else {
//            return nil
//        }
//        
//        // Take the last (most-recently) tapped sidebar layer; or the first non-selected layer.
//        let inspectedLayer = graph.layerFocusedInPropertyInspector
//        guard let inspectedLayerId = inspectedLayer,
//              let node = graph.getNodeViewModel(inspectedLayerId),
//              node.layerNode.isDefined else {
//            log("LayerInspectorView: No node for sidebar layer \(inspectedLayer)")
//            return nil
//        }
//        
//        return node
//    }
    
    @MainActor
    var layerInspectorData: (header: String,
                             node: NodeId?,
                             inputs: LayerInputObserverDict,
                             outputs: [OutputLayerNodeRowData])? {
        
        
        guard !graph.orderedSidebarLayers.isEmpty else {
            return nil
        }

        let selectedLayers = graph.sidebarSelectionState.nonEditModeSelections
        
        
        // multiselect
        if selectedLayers.count > 1 {
            guard let multiselectState = graph.graphUI.propertySidebar.layerMultiselectObserver else {
                log("Had multiple selected layers but no multiselect state")
                return nil
            }
            
            let inputs: LayerInputObserverDict = multiselectState.asLayerInputObserverDict
            
            return (header: "Multiselect",
                    node: nil,
                    inputs: inputs,
                    outputs: []) // TODO: multiselect: implement these
            
        }
        
        // else had 0 or 1 layers selected:
        else {
            let inspectedLayer = graph.layerFocusedInPropertyInspector
            guard let inspectedLayerId = inspectedLayer,
                  let node = graph.getNodeViewModel(inspectedLayerId),
                  let layerNode = node.layerNode else {
                log("LayerInspectorView: No node for sidebar layer \(inspectedLayer)")
                return nil
            }
            
            let inputs = layerNode.filteredLayerInputObserverDict(supportedInputs: layerNode.layer.inputDefinitions)
            
            return (header: node.displayTitle,
                    node: node.id,
                    inputs: inputs,
                    outputs: layerNode.outputPorts)
        }
        
//        // If no layers selected, then return last/first layer
//        if selectedLayers.isEmpty {
//            return nil
//        } else if selectedLayers.count == 1,
//                  let selectedLayer = selectedLayers.first {
//            
//        } else
    
    }
    
    // TODO: why can't we use
    @State var safeAreaInsets: EdgeInsets = .init()
    
    var body: some View {
//        if let node = selectedLayerNode,
//           let layerNode = node.layerNode {
//            @Bindable var node = node
//            @Bindable var layerNode = layerNode
        
        if let layerInspectorData = layerInspectorData {
            
            // Note: UIHostingController is adding safe area padding which is difficult to remove; so we read the safe areas and pad accordingly
            GeometryReader { geometry in
                UIKitWrapper(ignoresKeyCommands: false,
                             name: "LayerInspectorView") {
                    
                    selectedLayerView(
                        layerInspectorHeader: layerInspectorData.header,
                        node: layerInspectorData.node,
                        layerInputObserverDict: layerInspectorData.inputs,
                        layerOutputs: layerInspectorData.outputs)
                }
//                // TODO: Why subtract only half?
//                             .padding(.top, (-self.safeAreaInsets.top/2 + 8))
                             .padding(.bottom, (-self.safeAreaInsets.bottom))
                
                // TODO: why is this inaccurate?
                //                             .padding(.top, graph.graphUI.propertySidebar.safeAreaTopPadding)
                //                             .padding(.bottom, graph.graphUI.propertySidebar.safeAreaBottomPadding)
                
                             .onChange(of: geometry.safeAreaInsets, initial: true) { oldValue, newValue in
                                 //                                 log("safeAreaInsets: oldValue: \(oldValue)")
                                 //                                 log("safeAreaInsets: newValue: \(newValue)")
                                 self.safeAreaInsets = newValue
                                 graph.graphUI.propertySidebar.safeAreaTopPadding = -(newValue.top/2 + 8)
                                 //                                 graph.graphUI.propertySidebar.safeAreaBottomPadding = -newValue.bottom
                             }
            }
            
        } else {
            // Empty List, so have same background
            List { }
        }
    }
 
    @MainActor @ViewBuilder
    func selectedLayerView(layerInspectorHeader: String,
                           node: NodeId?,
                           // Represents the already-filtered layer input+observer for this specific layer
                           layerInputObserverDict: LayerInputObserverDict,
                           layerOutputs: [OutputLayerNodeRowData]) -> some View {

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // Only show editable layer node title if this isn't a multiselect case
                if let node = node {
                    StitchTitleTextField(graph: graph,
                                         titleEditType: .layerInspector(node),
                                         label: layerInspectorHeader,
                                         font: .title2)
                } else {
                    StitchTextView(string: layerInspectorHeader,
                                   font: .title2)
                }
                
                
                Spacer()
            }
                .padding()
                .background(WHITE_IN_LIGHT_MODE_GRAY_IN_DARK_MODE)
            
            List {
                ForEach(Self.unfilteredLayerInspectorRowsInOrder, id: \.name) { sectionNameAndInputs in
                    
//                ForEach(Self.layerInspectorRowsInOrder(layerNode.layer), id: \.name) { sectionNameAndInputs in
                    
                    let sectionName = sectionNameAndInputs.name
                    let sectionInputs = sectionNameAndInputs.inputs
                    
                    // (layer input + observer) for each layer input in this section that is actually supported by this specific layer
//                    let supportedInputsForThisLayer = layerNode.layer.inputDefinitions
                    
                    let filteredInputs: [LayerInputAndObserver] = sectionInputs.compactMap { sectionInput in
//                        guard supportedInputsForThisLayer.contains(sectionInput),
                        
                        let isSupported = layerInputObserverDict.get(sectionInput).isDefined
                        
                        guard isSupported,
                              let observer = layerInputObserverDict[sectionInput] else {
                            return nil
                        }
                        
                        return LayerInputAndObserver(
                            layerInput: sectionInput,
//                            portObserver: layerNode[keyPath: sectionInput.layerNodeKeyPath])
                            portObserver: observer)
                    }
                    
                    // TODO: when can this ever really be empty?
//                    if !sectionInputs.isEmpty {
                    if !filteredInputs.isEmpty {
                        LayerInspectorInputsSectionView(
                            sectionName: sectionName,
                            layerInputs: filteredInputs,
                            graph: graph
                        )
                    }
                } // ForEach
                
                LayerInspectorOutputsSectionView(
                    outputs: layerOutputs,
                    graph: graph)
            } // List
//            .listStyle(.plain)
//            .background(Color.SWIFTUI_LIST_BACKGROUND_COLOR)
                        
            // Note: hard to be exact here
            // The default ListStyle adds padding (visible if we do not use Color.clear as list row background), but using e.g. ListStyle.plain introduces sticky header sections that we do not want.
            .padding([.leading], -6)
            .padding([.trailing], -4)
        } // VStack
    }
}


struct LayerPropertyRowOriginReader: ViewModifier {
    
    @Bindable var graph: GraphState
    let layerInput: LayerInputPort
    
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

struct LayerInspectorSectionToggled: GraphUIEvent {
    let section: LayerInspectorSectionName
    
    func handle(state: GraphUIState) {
        let alreadyClosed = state.propertySidebar.collapsedSections.contains(section)
        if alreadyClosed {
            state.propertySidebar.collapsedSections.remove(section)
        } else {
            state.propertySidebar.collapsedSections.insert(section)
        }
    }
}

enum LayerInspectorSectionName: String, Equatable, Hashable {
    case sizing = "Sizing",
         positioning = "Positioning",
         common = "Common",
         group = "Group",
         pinning = "Pinning",
         typography = "Typography",
         stroke = "Stroke",
         rotation = "Rotation",
//         shadow = "Shadow",
         layerEffects = "Layer Effects"
}

// Named Tuple
typealias LayerInputAndObserver = (layerInput: LayerInputPort,
                                   portObserver: LayerInputObserver)

// This view now needs to receive the inputs it will be listing,
// rather than receiving the entire layer node.
struct LayerInspectorInputsSectionView: View {
    
    let sectionName: LayerInspectorSectionName
    
    // This section's layer inputs, filtered to excluded any not supported by this specific layer.
    let layerInputs: [LayerInputAndObserver]
    @Bindable var graph: GraphState

    
    @State private var expanded = true
      
    var body: some View {
        Section(isExpanded: $expanded) {
            ForEach(layerInputs, id: \.layerInput) { layerInput in
                let layerPort: LayerInputObserver = layerInput.portObserver
                
                // TODO: only using packed data here
                let allFieldsBlockedOut = layerPort._packedData.inspectorRowViewModel .fieldValueTypes.first?.fieldObservers.allSatisfy(\.isBlockedOut) ?? false
                
                if !allFieldsBlockedOut {
                    LayerInspectorInputPortView(portObserver: layerPort,
                                                graph: graph)
                    .modifier(LayerPropertyRowOriginReader(graph: graph,
                                                           layerInput: layerInput.layerInput))
                }
            }
            .transition(.slideInAndOut(edge: .top))
        } header: {
            // TODO: use a button instead?
            HStack(spacing: LAYER_INSPECTOR_ROW_SPACING) { // spacing of 8 ?
                let rotationZ: CGFloat = expanded ? 90 : 0
                Image(systemName: CHEVRON_GROUP_TOGGLE_ICON)
                    .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH,
                           height: LAYER_INSPECTOR_ROW_ICON_LENGTH)
                    .rotation3DEffect(Angle(degrees: rotationZ),
                                      axis: (x: 0, y: 0, z: rotationZ))
                    .animation(.linear(duration: 0.2), value: rotationZ)
                
                StitchTextView(string: sectionName.rawValue)
            }
            // Note: list row insets appear to be the only way to control padding on a list's section headers
            .listRowInsets(EdgeInsets(top: 0,
                                      leading: 0,
                                      bottom: 0,
                                      trailing: 0))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    self.expanded.toggle()
                    dispatch(LayerInspectorSectionToggled(section: sectionName))
                    
                    layerInputs.forEach { layerInput in
                        if case let .layerInput(x) = graph.graphUI.propertySidebar.selectedProperty,
                           x.layerInput == layerInput.layerInput {
                            graph.graphUI.propertySidebar.selectedProperty = nil
                        }
                    }
                }
            }
        }
    }
}

struct LayerInspectorOutputsSectionView: View {
    
//    @Bindable var node: NodeViewModel
//    @Bindable var layerNode: LayerNodeViewModel
    
    var outputs: [OutputLayerNodeRowData] // layerNode.outputPorts
    @Bindable var graph: GraphState
    
    var body: some View {
        
//        let outputs = layerNode.outputPorts
        
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
//                            node: node,
//                            layerNode: layerNode,
                            graph: graph, 
                            canvasItemId: output.canvasObserver?.id)
                    } else {
                        Color.clear.onAppear {
                            fatalErrorIfDebug("Did not have portId for layer node output")
                        }
                    }
                }
            } header: {
                HStack(spacing: LAYER_INSPECTOR_ROW_SPACING) {
                    Rectangle().fill(.clear)
                        .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH,
                               height: LAYER_INSPECTOR_ROW_ICON_LENGTH)
//                    
                    StitchTextView(string: "Outputs")
                }
                .listRowInsets(EdgeInsets(top: 0,
                                          leading: 0,
                                          bottom: 0,
                                          trailing: 0))
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


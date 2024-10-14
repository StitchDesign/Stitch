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
    // Figma design is actually ~277
//    static let LAYER_INSPECTOR_WIDTH = 360.0
//    static let LAYER_INSPECTOR_WIDTH = 277.0 // Figma
    
    // A little wider
    static let LAYER_INSPECTOR_WIDTH = 300.0
    
    @Bindable var graph: GraphState

    @State var safeAreaInsets: EdgeInsets = .init()
            
    var body: some View {
        
        if let layerInspectorData = graph.getLayerInspectorData() {
            
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
                .scrollContentBackground(.hidden)
//                .background {
//                    BLACK_IN_LIGHT_MODE_WHITE_IN_DARK_MODE
//                }
        }
    }
    
    @MainActor @ViewBuilder
    func selectedLayerView(layerInspectorHeader: String,
                           node: NodeId,
                           // Represents the already-filtered layer input+observer for this specific layer
                           layerInputObserverDict: LayerInputObserverDict,
                           layerOutputs: [OutputLayerNodeRowData]) -> some View {

        VStack(alignment: .leading, spacing: 0) {
            
#if DEBUG
            HStack {
                // Only show editable layer node title if this isn't a multiselect case
                StitchTitleTextField(graph: graph,
                                     titleEditType: .layerInspector(node),
                                     label: layerInspectorHeader,
                                     font: .title2)
                Spacer()
            }
            .padding()
            .background(WHITE_IN_LIGHT_MODE_GRAY_IN_DARK_MODE)
#endif
            
            List {
                ForEach(Self.unfilteredLayerInspectorRowsInOrder, id: \.name) { sectionNameAndInputs in
                    
                    let sectionName = sectionNameAndInputs.name
                    let sectionInputs = sectionNameAndInputs.inputs
                    
                    // Move this filtering to an onChange, and store the `filteredInputs` locally
                    // Or should live at
                    let filteredInputs: [LayerInputAndObserver] = sectionInputs.compactMap { sectionInput in
                        
                        let isSupported = layerInputObserverDict.get(sectionInput).isDefined
                        
                        guard isSupported,
                              let observer = layerInputObserverDict[sectionInput] else {
                            return nil
                        }
                        
                        return LayerInputAndObserver(
                            layerInput: sectionInput,
                            portObserver: observer)
                    }
                    
                    if !filteredInputs.isEmpty {
                        LayerInspectorInputsSectionView(
                            sectionName: sectionName,
                            layerInputs: filteredInputs,
                            graph: graph,
                            nodeId: node
                        )
                    }
                } // ForEach
                .padding(.horizontal)
                
                LayerInspectorOutputsSectionView(
                    outputs: layerOutputs,
                    graph: graph)
                .padding(.horizontal)
            } // List
            .listSectionSpacing(.compact) // reduce spacing between sections
            .scrollContentBackground(.hidden)
            
            // Note: Need to use `.plain` style so that layers with fewer sections (e.g. Linear Gradient layer, vs Text layer) do not default to a different list style;
            // And using .plain requires manually adding trailing and leading padding
            .listStyle(.plain)
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
    let nodeId: NodeId
    
    @State private var expanded = true
    @State private var isHovered = false
      
    var body: some View {
        Section(isExpanded: $expanded) {
            ForEach(layerInputs, id: \.layerInput) { layerInput in
                let layerInputObserver: LayerInputObserver = layerInput.portObserver
                
                let blockedFields = layerInputObserver.blockedFields
                
                let allFieldsBlockedOut = layerInputObserver
                    .fieldValueTypes.first?
                    .fieldObservers.allSatisfy({ $0.isBlocked(blockedFields)})
                ?? false
                
                if !allFieldsBlockedOut {
                    LayerInspectorInputPortView(layerInputObserver: layerInputObserver,
                                                graph: graph,
                                                nodeId: nodeId)
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
                    .opacity(self.isHovered ? 1 : 0)
                
                StitchTextView(string: sectionName.rawValue,
                               font: stitchFont(18))
                    .textCase(nil)
                    .bold()
            }
            // Note: list row insets appear to be the only way to control padding on a list's section headers
            .listRowInsets(EdgeInsets(top: 0,
                                      leading: 0,
                                      bottom: 0,
                                      trailing: 0))
            .contentShape(Rectangle())
            .onHover {
                self.isHovered = $0
            }
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
    
    var outputs: [OutputLayerNodeRowData] // layerNode.outputPorts
    @Bindable var graph: GraphState
    
    var body: some View {
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
                    
                    StitchTextView(string: "Outputs").textCase(nil)
                }
                .listRowInsets(EdgeInsets(top: 0,
                                          leading: 0,
                                          bottom: 0,
                                          trailing: 0))
            }
        }
    }
}

extension GraphState {
    
    // Note: just used for `LayerInspectorView`
    @MainActor
    func getLayerInspectorData() -> (header: String,
                                     node: NodeId,
                                     inputs: LayerInputObserverDict,
                                     outputs: [OutputLayerNodeRowData])? {
                
        // Any time orderedSidebarLayers changes, that will retrigger LayerInspector
        guard !self.orderedSidebarLayers.isEmpty else {
            return nil
        }

        var selectedLayers = self.sidebarSelectionState.inspectorFocusedLayers.focused
        
        #if DEV_DEBUG
        // For debug
        if selectedLayers.isEmpty,
           let layer = self.layerNodes.keys.first {
            selectedLayers = .init([.init(layer)])
        }
        #endif
        
        // multiselect
        if selectedLayers.count > 1 {
            guard let firstLayer = selectedLayers.first,
                  let multiselectState = self.graphUI.propertySidebar.inputsCommonToSelectedLayers else {
                log("Had multiple selected layers but no multiselect state")
                return nil
            }
            
            let inputs: LayerInputObserverDict = multiselectState.asLayerInputObserverDict(self)
            
            return (header: "Multiselect",
//                    node: nil,
                    // TODO: is this bad? grabbing
                    node: firstLayer.asNodeId,
                    inputs: inputs,
                    outputs: []) // TODO: multiselect for outputs
            
        }
        
        // else had 0 or 1 layers selected:
        else {
            guard let inspectedLayerId = self.sidebarSelectionState.inspectorFocusedLayers.focused.first?.id,
                  let node = self.getNodeViewModel(inspectedLayerId),
                  let layerNode = node.layerNode else {
                // log("LayerInspectorView: No inspector-focused layers?:  \(self.sidebarSelectionState.inspectorFocusedLayers)")
                return nil
            }
            
            let inputs = layerNode.filteredLayerInputObserverDict(supportedInputs: layerNode.layer.inputDefinitions)
            
            return (header: node.displayTitle,
                    node: node.id,
                    inputs: inputs,
                    outputs: layerNode.outputPorts)
        }
    }
}

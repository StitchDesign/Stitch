//
//  LayerInspectorView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/16/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

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
//    static let LAYER_INSPECTOR_WIDTH = 300.0
#if targetEnvironment(macCatalyst)
    static let LAYER_INSPECTOR_WIDTH = 324.0
#else
//    static let LAYER_INSPECTOR_WIDTH = 300.0
    static let LAYER_INSPECTOR_WIDTH = 280.0
#endif
    
    @Bindable var graph: GraphState

    @State var safeAreaInsets: EdgeInsets = .init()
            
    var layerInspectorData: (header: String,
                             node: NodeId,
                             inputs: LayerInputObserverDict,
                             outputs: [OutputLayerNodeRowData])? {
        graph.getLayerInspectorData()
    }
    
    var body: some View {
        
        if let layerInspectorData = layerInspectorData {
            selectedLayerView(
                layerInspectorHeader: layerInspectorData.header,
                node: layerInspectorData.node,
                layerInputObserverDict: layerInspectorData.inputs,
                layerOutputs: layerInspectorData.outputs)
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
                        
            List {
                ForEach(LayerInspectorSection.allCases) { section in
                    let sectionInputs = section.sectionData
                    
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
                            section: section,
                            layerInputs: .init(layerInputs: filteredInputs),
                            graph: graph,
                            nodeId: node
                        )
                    }
                } // ForEach
                .padding(.horizontal)
                #if targetEnvironment(macCatalyst)
                .padding(.trailing, LAYER_INSPECTOR_ROW_SPACING + LAYER_INSPECTOR_ROW_ICON_LENGTH)
                #endif
                
                LayerInspectorOutputsSectionView(
                    outputs: layerOutputs,
                    graph: graph)
                .padding(.horizontal)
                #if targetEnvironment(macCatalyst)
                .padding(.trailing, LAYER_INSPECTOR_ROW_SPACING + LAYER_INSPECTOR_ROW_ICON_LENGTH)
                #endif
                .padding(.bottom)
                
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
    let section: LayerInspectorSection
    
    func handle(state: GraphUIState) {
        let alreadyClosed = state.propertySidebar.collapsedSections.contains(section)
        if alreadyClosed {
            state.propertySidebar.collapsedSections.remove(section)
        } else {
            state.propertySidebar.collapsedSections.insert(section)
        }
    }
}

@Observable
final class LayerInputAndObserver {
    let layerInput: LayerInputPort
    let portObserver: LayerInputObserver
    
    init(layerInput: LayerInputPort,
         portObserver: LayerInputObserver) {
        self.layerInput = layerInput
        self.portObserver = portObserver
    }
}

@Observable
final class LayerInputsAndObservers {
    let layerInputs: [LayerInputAndObserver]
    
    init(layerInputs: [LayerInputAndObserver]) {
        self.layerInputs = layerInputs
    }
}

struct LayerInspectorInputView: View {
    
    // `@Bindable var` (vs. `let`) seems to improve a strange issue where toggling scroll-enabled input on iPad would update the LayerInputObserver's blockedFields set but not re-render the view.
    @Bindable var layerInput: LayerInputAndObserver
    @Bindable var graph: GraphState
    let nodeId: NodeId
    
    var body: some View {
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
        } else {
            EmptyView()
        }
    }
    
}

struct LayerInspectorSectionHeader: View {
    let string: String

    var body: some View {
        StitchTextView(string: string,
                       font: stitchFont(18))
            .textCase(nil)
            .bold()
    }
}

// This view now needs to receive the inputs it will be listing,
// rather than receiving the entire layer node.
struct LayerInspectorInputsSectionView: View {
    
    let section: LayerInspectorSection
    
    // This section's layer inputs, filtered to excluded any not supported by this specific layer.
    @Bindable var layerInputs: LayerInputsAndObservers
    @Bindable var graph: GraphState
    let nodeId: NodeId
    
    @State private var expanded = true
    @State private var isHovered = false
      
    var body: some View {
        Section(isExpanded: $expanded) {
            ForEach(layerInputs.layerInputs, id: \.layerInput) { (layerInput: LayerInputAndObserver) in
                LayerInspectorInputView(layerInput: layerInput,
                                        graph: graph,
                                        nodeId: nodeId)
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
                
                LayerInspectorSectionHeader(string: section.rawValue)
                
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
                    dispatch(LayerInspectorSectionToggled(section: section))
                    
                    layerInputs.layerInputs.forEach { layerInput in
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
                    
                    LayerInspectorSectionHeader(string: "Outputs")
                    
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
        // log("getLayerInspectorData called")
                
        // Any time orderedSidebarLayers changes, that will retrigger LayerInspector
        guard !self.orderedSidebarLayers.isEmpty else {
            return nil
        }

        var inspectorFocusedLayers = self.layersSidebarViewModel.selectionState.primary
        
        // log("getLayerInspectorData: inspectorFocusedLayers: \(inspectorFocusedLayers)")
        
        #if DEV_DEBUG
        // For debug
        if inspectorFocusedLayers.isEmpty,
           let layer = self.layerNodes.keys.first {
            inspectorFocusedLayers = .init([layer])
        }
        #endif
        
        // multiselect
        if inspectorFocusedLayers.count > 1 {
            guard let firstLayer = inspectorFocusedLayers.first,
                  let multiselectState = self.graphUI.propertySidebar.inputsCommonToSelectedLayers else {
                log("getLayerInspectorData: Had multiple selected layers but no multiselect state")
                return nil
            }
            
            let inputs: LayerInputObserverDict = multiselectState.asLayerInputObserverDict(self)
            
            return (header: "Multiselect",
//                    node: nil,
                    // TODO: is this bad? grabbing
                    node: firstLayer,
                    inputs: inputs,
                    outputs: []) // TODO: multiselect for outputs
            
        }
        
        // else had 0 or 1 layers selected:
        else {
            guard let inspectedLayerId = self.layersSidebarViewModel.selectionState.primary.first,
                  let node = self.getNodeViewModel(inspectedLayerId),
                  let layerNode = node.layerNode else {
                // log("getLayerInspectorData: No inspector-focused layers?:  \(inspectorFocusedLayers)")
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

//
//  NodeInputView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

struct LayerInspectorRowButton: View {
    
    let layerProperty: LayerInspectorRowId
    let coordinate: NodeIOCoordinate
    let canvasItemId: CanvasItemId?
    let isRowSelected: Bool
    let isHovered: Bool
    
    var canBeAddedToCanvas: Bool {
        switch layerProperty {
        case .layerInput(let layerInputType):
            return !layerInputType.layerInput.usesFlyout
        case .layerOutput(let int):
            return true
        }
    }
    
    var showAddLayerPropertyButton: Bool {
        if canvasItemId.isDefined {
            return false
        }
        
        if isHovered {
            return true
        }
        
        if canBeAddedToCanvas, isRowSelected {
            return true
        }
        
        return false
    }
    
    var body: some View {
        if let canvasItemId = canvasItemId {
            JumpToLayerPropertyOnGraphButton(canvasItemId: canvasItemId)
        } else {
            AddLayerPropertyToGraphButton(coordinate: coordinate)
                .opacity(showAddLayerPropertyButton ? 1 : 0)
                .animation(.default, value: showAddLayerPropertyButton)
        }
    }
}

// TODO: revisit this when we're able to add LayerNodes with outputs to the graph again
struct AddLayerPropertyToGraphButton: View {
    let coordinate: NodeIOCoordinate
    
    var nodeId: NodeId {
        coordinate.nodeId
    }
    
    var body: some View {
        Image(systemName: "plus.circle")
            .resizable()
            .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH, 
                   height: LAYER_INSPECTOR_ROW_ICON_LENGTH) // per Figma
            .onTapGesture {
                if let layerInput = coordinate.keyPath {
                    dispatch(LayerInputAddedToGraph(
                        nodeId: nodeId,
                        coordinate: layerInput))
                } else if let portId = coordinate.portId {
                    dispatch(LayerOutputAddedToGraph(nodeId: nodeId,
                                                     portId: portId))
                }
            }
    }
}

struct JumpToLayerPropertyOnGraphButton: View {
    let canvasItemId: CanvasItemId
        
    var body: some View {
        // TODO: use a button ?
        Image(systemName: "scope")
            .resizable()
            .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH, 
                   height: LAYER_INSPECTOR_ROW_ICON_LENGTH)
            .onTapGesture {
                dispatch(JumpToCanvasItem(id: canvasItemId))
            }
    }
}

struct NodeInputOutputView<NodeRowObserverType: NodeRowObserver,
                           FieldsView: View>: View {
    typealias NodeRowType = NodeRowObserverType.RowViewModelType
    
    @State private var showPopover: Bool = false
    
    @Bindable var graph: GraphState
    @Bindable var rowObserver: NodeRowObserverType
    @Bindable var rowData: NodeRowType
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    @ViewBuilder var fieldsView: (NodeRowType, LabelDisplayView) -> FieldsView
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
    @MainActor
    var label: String {
        if isGroupNode {
            return rowObserver.nodeDelegate?.displayTitle ?? ""
        }
        
        return self.rowObserver.label(forPropertySidebar)
    }
    
    var isGroupNode: Bool {
        self.rowData.nodeDelegate?.kind.isGroup ?? false
    } 
    
    var body: some View {
            // Fields and port ordering depending on input/output
            self.fieldsView(rowData, labelView)
        
        // Don't specify height for layer inspector property row, so that multifields can be shown vertically
        .frame(height: forPropertySidebar ? nil : NODE_ROW_HEIGHT)

        .padding([.top, .bottom], forPropertySidebar ? 8 : 0)
        
        .onChange(of: self.graphUI.activeIndex) {
            let oldViewValue = self.rowData.activeValue
            let newViewValue = self.rowObserver.activeValue
            self.rowData.activeValueChanged(oldValue: oldViewValue,
                                            newValue: newViewValue)
        }
        .modifier(EdgeEditModeViewModifier(graphState: graph,
                                           portId: rowData.id.portId,
                                           nodeId: self.rowData.canvasItemDelegate?.id,
                                           nodeIOType: NodeRowType.nodeIO,
                                           forPropertySidebar: forPropertySidebar))
    }
    
    @ViewBuilder @MainActor
    var labelView: LabelDisplayView {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR)
    }
}

struct NodeInputView: View {
    @State private var showPopover: Bool = false
    
    @Bindable var graph: GraphState
    @Bindable var rowObserver: InputNodeRowObserver
    @Bindable var rowData: InputNodeRowObserver.RowViewModelType
    let inputLayerNodeRowData: InputLayerNodeRowData?
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isCanvasItemSelected: Bool
    
    var forFlyout: Bool = false
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
    var nodeId: NodeId {
        self.rowObserver.id.nodeId
    }
    
    // pass in instead of accessing via nodeDelegate
    var nodeKind: NodeKind {
        self.rowObserver.nodeDelegate?.kind ?? .patch(.splitter)
    }
        
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: InputFieldViewModel,
                        isMultiField: Bool) -> some View {
        InputValueEntry(graph: graph,
                        rowViewModel: rowData,
                        viewModel: portViewModel, 
                        inputLayerNodeRowData: inputLayerNodeRowData,
                        rowObserverId: rowObserver.id,
                        nodeKind: nodeKind,
                        isCanvasItemSelected: isCanvasItemSelected,
                        hasIncomingEdge: rowObserver.upstreamOutputObserver.isDefined,
                        forPropertySidebar: forPropertySidebar,
                        propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
    }
    
    var layerInput: LayerInputPort? {
        rowData.rowDelegate?.id.keyPath?.layerInput
    }
    
    var body: some View {
        NodeInputOutputView(graph: graph,
                            rowObserver: rowObserver,
                            rowData: rowData,
                            forPropertySidebar: forPropertySidebar,
                            propertyIsSelected: propertyIsSelected) { inputViewModel, labelView in
           
            // For multifields, want the overall label to sit at top of fields' VStack.
            // For single fields, want to the overall label t
            HStack(alignment: hStackAlignment) {
                
                if !forPropertySidebar {
                    NodeRowPortView(graph: graph,
                                    rowObserver: rowObserver,
                                    rowViewModel: rowData,
                                    showPopover: $showPopover)
                }
                
                // Alternatively, look at input's values instead of the `LayerInputPort` ?
                // let isPaddingInput = rowObserver.values.first?.getPadding
                let usesPaddingFlyout = self.layerInput?.usesPaddingFlyout ?? false
                
                let isShadowLayerInputRow = self.layerInput == SHADOW_FLYOUT_LAYER_INPUT_PROXY
                
                if usesPaddingFlyout,
                   forPropertySidebar,
                   let paddingLayerInput = self.layerInput {
                    PaddingReadOnlyView(rowObserver: rowObserver,
                                        rowData: rowData,
                                        labelView: labelView,
                                        paddingLayerInput: paddingLayerInput)
                    
                } else if isShadowLayerInputRow,
                          forPropertySidebar,
                          !forFlyout {
                    HStack {
                        StitchTextView(string: "Shadow",
                                       fontColor: STITCH_FONT_GRAY_COLOR)
                        Spacer()
                        
                    }
                    .overlay {
                        Color.white.opacity(0.001)
                            .onTapGesture {
                                dispatch(FlyoutToggled(
                                    flyoutInput: SHADOW_FLYOUT_LAYER_INPUT_PROXY,
                                    flyoutNodeId: nodeId))
                            }
                    }
                    
                } else {
                    labelView
                    
                    FieldsListView(graph: graph,
                                   rowViewModel: rowData,
                                   nodeId: nodeId,
                                   isGroupNodeKind: rowObserver.nodeDelegate?.kind.isGroup ?? false,
                                   forPropertySidebar: forPropertySidebar,
                                   propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                   valueEntryView: valueEntryView)
                }
            } // HStack
        }
    }
    
    var hStackAlignment: VerticalAlignment {
        (forPropertySidebar && isMultiField) ? .firstTextBaseline : .center
    }
    
    var isMultiField: Bool {
        (self.rowData.fieldValueTypes.first?.fieldObservers.count ?? 0) > 1
    }
}

struct NodeOutputView: View {
    @State private var showPopover: Bool = false
    
    @Bindable var graph: GraphState
    
    @Bindable var rowObserver: OutputNodeRowObserver
    @Bindable var rowData: OutputNodeRowObserver.RowViewModelType
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isCanvasItemSelected: Bool
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
    var nodeId: NodeId {
        self.rowObserver.id.nodeId
    }
    
    var nodeKind: NodeKind {
        self.rowObserver.nodeDelegate?.kind ?? .patch(.splitter)
    }
    
    var isSplitter: Bool {
        self.nodeKind == .patch(.splitter)
    }
        
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: OutputFieldViewModel,
                        isMultiField: Bool) -> some View {
        OutputValueEntry(graph: graph,
                         rowViewModel: rowData,
                         viewModel: portViewModel,
                         coordinate: rowObserver.id,
                         isMultiField: isMultiField,
                         nodeKind: nodeKind,
                         isCanvasItemSelected: isCanvasItemSelected,
                         forPropertySidebar: forPropertySidebar,
                         propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
    }
    
    var body: some View {
        NodeInputOutputView(graph: graph,
                            rowObserver: rowObserver,
                            rowData: rowData,
                            forPropertySidebar: forPropertySidebar,
                            propertyIsSelected: propertyIsSelected) { outputViewModel, labelView in
            HStack(alignment: forPropertySidebar ? .firstTextBaseline: .center) {
                // Property sidebar always shows labels on left side, never right
                if forPropertySidebar {
                    labelView
                    
                    // TODO: fields in layer-inspector flush with right screen edge?
                    //                    Spacer()
                }
                
                // Hide outputs for value node
                if !isSplitter {
                    FieldsListView(graph: graph,
                                   rowViewModel: rowData,
                                   nodeId: nodeId,
                                   isGroupNodeKind: nodeKind.isGroup,
                                   forPropertySidebar: forPropertySidebar,
                                   propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                   valueEntryView: valueEntryView)
                }
                
                if !forPropertySidebar {
                    labelView
                    NodeRowPortView(graph: graph,
                                    rowObserver: rowObserver,
                                    rowViewModel: rowData,
                                    showPopover: $showPopover)
                }
            }
        }
    }
}

struct FieldsListView<PortType, ValueEntryView>: View where PortType: NodeRowViewModel, ValueEntryView: View {
    @Bindable var graph: GraphState
    @Bindable var rowViewModel: PortType
    let nodeId: NodeId
    let isGroupNodeKind: Bool
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    @ViewBuilder var valueEntryView: (PortType.FieldType, Bool) -> ValueEntryView
    
    var isMultiField: Bool {
        self.rowViewModel.fieldValueTypes.count > 1
    }
    
    var body: some View {
        ForEach(rowViewModel.fieldValueTypes) { (fieldGroupViewModel: FieldGroupTypeViewModel<PortType.FieldType>) in
            NodeFieldsView(
                graph: graph,
                fieldGroupViewModel: fieldGroupViewModel,
                nodeId: nodeId,
                isGroupNodeKind: isGroupNodeKind,
                isMultiField: isMultiField,
                forPropertySidebar: forPropertySidebar,
                propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                valueEntryView: valueEntryView
            )
        }
    }
}

struct NodeRowPortView<NodeRowObserverType: NodeRowObserver>: View {
    @Bindable var graph: GraphState
    @Bindable var rowObserver: NodeRowObserverType
    @Bindable var rowViewModel: NodeRowObserverType.RowViewModelType
    
    @Binding var showPopover: Bool
    
    var coordinate: NodeIOPortType {
        self.rowObserver.id.portType
    }
    
    var nodeIO: NodeIO {
        NodeRowObserverType.nodeIOType
    }
    
    var isGroup: Bool {
        self.rowObserver.nodeDelegate?.kind.isGroup ?? false
    }
    
    var body: some View {
        PortEntryView(rowViewModel: rowViewModel,
                      graph: graph,
                      coordinate: coordinate)
        /*
         In practice, seems okay; e.g. Loop node changing from 3 to 1 disables the tap, and changing from 1 to 3 enables the tap.
         */
        .onTapGesture {
            // Do nothing when input/output doesn't contain a loop
            if rowObserver.hasLoopedValues {
                self.showPopover.toggle()
            } else {
                // If input/output count is no longer a loop,
                // any tap should just close the popover.
                self.showPopover = false
            }
        }
        // TODO: get popover to work with all values
        .popover(isPresented: $showPopover) {
            // Conditional is a hack that cuts down on perf
            if showPopover {
                PortValuesPreviewView(data: rowObserver,
                                      fieldValueTypes: rowViewModel.fieldValueTypes,
                                      coordinate: self.rowObserver.id,
                                      nodeIO: nodeIO)
            }
        }
    }
}

//#Preview {
//    NodeInputOutputView(graph: <#T##GraphState#>,
//                        node: <#T##NodeViewModel#>,
//                        rowData: <#T##NodeRowObserver#>,
//                        coordinateType: <#T##PortViewType#>,
//                        nodeKind: <#T##NodeKind#>,
//                        isNodeSelected: <#T##Bool#>,
//                        adjustmentBarSessionId: <#T##AdjustmentBarSessionId#>)
//}

// struct SpecNodeInputView_Previews: PreviewProvider {
//    static var previews: some View {
//        let coordinate = Coordinate.input(InputCoordinate(portId: 0, nodeId: .init()))
//
//        NodeInputOutputView(valueObserver: .init(initialValue: .number(999),
//                                                 coordinate: coordinate,
//                                                 valuesCount: 1,
//                                                 isInFrame: true),
//                            valuesObserver: .init([.number(999)], coordinate),
//                            isInput: true,
//                            label: "",
//                            nodeKind: .patch(.add),
//                            focusedField: nil,
//                            layerNames: .init(),
//                            broadcastChoices: .init(),
//                            edges: .init(),
//                            selectedEdges: nil,
//                            nearestEligibleInput: nil,
//                            edgeDrawingGesture: .none)
//            .previewDevice(IPAD_PREVIEW_DEVICE_NAME)
//    }
// }

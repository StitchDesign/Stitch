//
//  NodeInputView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

struct NodeInputOutputView<NodeRowType: NodeRowViewModel,
                           FieldsView: View>: View {
    @State private var showPopover: Bool = false
    
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var rowObserver: NodeRowObserver
    @Bindable var rowData: NodeRowType
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    let propertyIsAlreadyOnGraph: Bool
    let portTapAction: (LayerInputType) -> ()
    @ViewBuilder var fieldsView: (NodeRowType, LabelDisplayView) -> FieldsView
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
    var body: some View {
        let coordinate = rowData.id
        HStack(spacing: NODE_COMMON_SPACING) {
            if forPropertySidebar,
               let layerInput = rowObserver.id.keyPath {
                Image(systemName: "plus.circle")
                    .resizable()
                    .frame(width: 15, height: 15)
                    .onTapGesture {
                        portTapAction(layerInput)
                    }
                    .opacity(propertyIsSelected ? 1 : 0)
            }
            
            // Fields and port ordering depending on input/output
            self.fieldsView(rowData, labelView)
        }
        .frame(height: NODE_ROW_HEIGHT)
        .onChange(of: self.graph.graphUI.activeIndex) {
            let oldViewValue = self.rowObserver.activeValue
            let newViewValue = self.rowObserver.getActiveValue(activeIndex: self.graphUI.activeIndex)
            self.rowData.activeValueChanged(oldValue: oldViewValue,
                                            newValue: newViewValue)
        }
        .modifier(EdgeEditModeViewModifier(graphState: graph,
                                           portId: coordinate.portId,
                                           nodeId: coordinate.nodeId,
                                           nodeIOType: self.rowData.nodeIOType,
                                           forPropertySidebar: forPropertySidebar))
    }
    
    @ViewBuilder @MainActor
    var labelView: LabelDisplayView {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR)
    }
}

struct NodePortLabelView: View {
    let label: String
    
    var body: some View {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR)
    }
}

struct NodeInputView: View {
    @State private var showPopover: Bool = false
    
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvasItem: CanvasItemViewModel
    @Bindable var rowObserver: NodeRowObserver
    @Bindable var rowData: InputNodeRowViewModel
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    let propertyIsAlreadyOnGraph: Bool
    @Binding var isButtonPressed: Bool
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
    var nodeId: NodeId {
        self.rowObserver.id.nodeId
    }
    
    var isSplitter: Bool {
        self.node.kind == .patch(.splitter)
    }
    
    @MainActor func onPortTap(layerInputType: LayerInputType) {
        dispatch(LayerInputAddedToGraph(
            nodeId: nodeId,
            coordinate: layerInputType))
    }
    
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: InputFieldViewModel,
                        isMultiField: Bool) -> some View {
        InputValueEntry(graph: graph,
                        rowObserver: rowObserver,
                        viewModel: portViewModel,
                        fieldCoordinate: ,
                        nodeKind: node.kind,
                        isCanvasItemSelected: canvasItem.isSelected,
                        hasIncomingEdge: rowObserver.upstreamOutputObserver.isDefined,
                        forPropertySidebar: forPropertySidebar,
                        propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
    }

    var body: some View {
        NodeInputOutputView(graph: graph,
                            node: node,
                            rowObserver: rowObserver,
                            rowData: rowData,
                            forPropertySidebar: forPropertySidebar,
                            propertyIsSelected: propertyIsSelected,
                            propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                            portTapAction: onPortTap) { inputViewModel, labelView in
            HStack {
                if !forPropertySidebar {
                    NodeRowPortView(graph: graph,
                                    node: node,
                                    rowData: rowObserver,
                                    showPopover: $showPopover,
                                    coordinate: .input(inputViewModel.id))
                }
                
                labelView
                
                FieldsListView(graph: graph,
                               rowObserver: rowObserver,
                               rowViewModel: rowData,
                               isGroupNodeKind: !node.kind.isGroup,
                               forPropertySidebar: forPropertySidebar,
                               propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                               valueEntryView: valueEntryView)
            }
        }
    }
}

struct NodeOutputView: View {
    @State private var showPopover: Bool = false
    
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvasItem: CanvasItemViewModel
    @Bindable var rowObserver: NodeRowObserver
    @Bindable var rowData: OutputNodeRowViewModel
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    let propertyIsAlreadyOnGraph: Bool
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
    var nodeId: NodeId {
        self.rowObserver.id.nodeId
    }
    
    var isSplitter: Bool {
        self.node.kind == .patch(.splitter)
    }
    
    @MainActor func onPortTap(layerInputType: LayerInputType) {
        dispatch(LayerOutputAddedToGraph(
            nodeId: nodeId,
            coordinate: rowData.id))
    }
    
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: OutputFieldViewModel,
                        isMultiField: Bool) -> some View {
        OutputValueEntry(graph: graph,
                         rowObserver: rowObserver,
                         viewModel: portViewModel,
                         isMultiField: isMultiField,
                         nodeKind: node.kind,
                         isCanvasItemSelected: canvasItem.isSelected,
                         forPropertySidebar: forPropertySidebar,
                         propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
    }

    var body: some View {
        NodeInputOutputView(graph: graph,
                            node: node,
                            rowObserver: rowObserver,
                            rowData: rowData,
                            forPropertySidebar: forPropertySidebar,
                            propertyIsSelected: propertyIsSelected,
                            propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                            portTapAction: onPortTap) { outputViewModel, labelView in
            HStack {
                // Property sidebar always shows labels on left side, never right
                if forPropertySidebar {
                    labelView
                }
                
                // Hide outputs for value node
                if !isSplitter {
                    FieldsListView(graph: graph,
                                   rowObserver: rowObserver,
                                   rowViewModel: rowData,
                                   isGroupNodeKind: !node.kind.isGroup,
                                   forPropertySidebar: forPropertySidebar,
                                   propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                   valueEntryView: valueEntryView)
                }
                
                if !forPropertySidebar {
                    labelView
                    NodeRowPortView(graph: graph,
                                    node: node,
                                    rowData: rowObserver,
                                    showPopover: $showPopover,
                                    coordinate: .output(rowData.id))
                }
            }
        }
    }
}

struct FieldsListView<PortType, ValueEntryView>: View where PortType: NodeRowViewModel, ValueEntryView: View {
    @Bindable var graph: GraphState
    @Bindable var rowObserver: NodeRowObserver
    @Bindable var rowViewModel: PortType
    let isGroupNodeKind: Bool
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    @ViewBuilder var valueEntryView: (PortType.FieldType, Bool) -> ValueEntryView
    
    var isMultiField: Bool {
        self.rowViewModel.fieldValueTypes.count > 1
    }
    
    var body: some View {
        ForEach(rowViewModel.fieldValueTypes) { fieldGroupViewModel in
            NodeFieldsView(
                graph: graph,
                fieldGroupViewModel: fieldGroupViewModel,
                nodeId: rowObserver.id.nodeId,
                isGroupNodeKind: isGroupNodeKind,
                isMultiField: isMultiField,
                forPropertySidebar: forPropertySidebar,
                propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                valueEntryView: valueEntryView
            )
        }
    }
}

struct NodeRowPortView: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
//    @Bindable var canvasItem: CanvasItemViewModel
    @Bindable var rowData: NodeRowObserver

    @Binding var showPopover: Bool
    let coordinate: PortViewType

    @MainActor
    var hasIncomingEdge: Bool {
        self.rowData.upstreamOutputObserver.isDefined
    }

    var nodeIO: NodeIO {
        self.rowData.nodeIOType
    }
    
    var nodeDelegate: NodeDelegate? {
        let isSplitterRowAndInvisible = node.kind.isGroup && rowData.nodeDelegate?.id != node.id
        
        // Use passed-in group node so we can obtain view-pertinent information for splitters.
        // Fixes issue where output splitters use wrong node delegate.
        if isSplitterRowAndInvisible {
            return node
        }
        
        return rowData.nodeDelegate
    }

    var body: some View {
        PortEntryView(rowObserver: rowData,
                      graph: graph,
                      coordinate: coordinate,
                      color: self.rowData.portColor, 
                      nodeDelegate: nodeDelegate)
        /*
         In practice, seems okay; e.g. Loop node changing from 3 to 1 disables the tap, and changing from 1 to 3 enables the tap.
         */
        .onTapGesture {
            // Do nothing when input/output doesn't contain a loop
            if rowData.hasLoopedValues {
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
                PortValuesPreviewView(data: rowData,
                                      coordinate: self.rowData.id,
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

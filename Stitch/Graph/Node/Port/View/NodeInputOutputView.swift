//
//  NodeInputView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

struct NodeInputOutputView<NodeRowObserverType: NodeRowObserver,
                           FieldsView: View>: View {
    typealias NodeRowType = NodeRowObserverType.RowViewModelType
    
    @State private var showPopover: Bool = false
    
    @Bindable var graph: GraphState
    @Bindable var rowObserver: NodeRowObserverType
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
    
    @MainActor
    var label: String {
        self.rowObserver.label(forPropertySidebar)
    }
    
    var body: some View {
        let coordinate = rowData.id
        HStack(alignment: .firstTextBaseline, spacing: NODE_COMMON_SPACING) {
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
//        .frame(height: NODE_ROW_HEIGHT)
        
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
                                           portId: coordinate.coordinate.portId,
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
    
    var isSplitter: Bool {
        self.nodeKind == .patch(.splitter)
    }
    
    var nodeKind: NodeKind {
        self.rowObserver.nodeDelegate?.kind ?? .patch(.splitter)
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
                        rowViewModel: rowData,
                        viewModel: portViewModel,
                        nodeKind: nodeKind,
                        isCanvasItemSelected: isCanvasItemSelected,
                        hasIncomingEdge: rowObserver.upstreamOutputObserver.isDefined,
                        forPropertySidebar: forPropertySidebar,
                        propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
    }

    var body: some View {
        NodeInputOutputView(graph: graph,
                            rowObserver: rowObserver,
                            rowData: rowData,
                            forPropertySidebar: forPropertySidebar,
                            propertyIsSelected: propertyIsSelected,
                            propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                            portTapAction: onPortTap) { inputViewModel, labelView in
            HStack {
                if !forPropertySidebar {
                    NodeRowPortView(graph: graph,
                                    rowObserver: rowObserver,
                                    rowViewModel: rowData,
                                    showPopover: $showPopover)
                }

                let isPaddingLayerInputRow = rowData.id.keyPath == .padding
                let hidePaddingFieldsOnPropertySidebar = isPaddingLayerInputRow && forPropertySidebar
                
                if hidePaddingFieldsOnPropertySidebar {
                    Group {
                        labelView
                        
                        Spacer()
                        
                        // Want to just display the values; so need a new kind of `display only` view
                        ForEach(rowData.fieldValueTypes) { fieldGroupViewModel in
                            
                            ForEach(fieldGroupViewModel.fieldObservers)  { (fieldViewModel: FieldViewModel) in
                                
                                StitchTextView(string: fieldViewModel.fieldValue.stringValue,
                                               fontColor: STITCH_FONT_GRAY_COLOR)
                                // Monospacing prevents jittery node widths if values change on graphstep
                                .monospacedDigit()
                                // TODO: what is best width? Needs to be large enough for 3-digit values?
                                .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH - 12)
                                .background {
                                    INPUT_FIELD_BACKGROUND.cornerRadius(4)
                                }
                            }
                            
                        } // Group
                        
                        // Tap on the read-only fields to open padding flyout
                        .onTapGesture {
                            dispatch(FlyoutToggled(flyoutInput: .padding,
                                                   flyoutNodeId: inputCoordinate.nodeId))
                        }
                    }                    
                } else {
                    labelView
                    FieldsListView(graph: graph,
                                rowViewModel: rowData,
                                nodeId: nodeId,
                                isGroupNodeKind: !(rowObserver.nodeDelegate?.kind.isGroup ?? true),
                                forPropertySidebar: forPropertySidebar,
                                propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                valueEntryView: valueEntryView)
                }
            
            }
        }
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
    
    @MainActor func onPortTap(layerInputType: LayerInputType) {
        dispatch(LayerOutputAddedToGraph(
            nodeId: nodeId,
            coordinate: rowData.id.portType))
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
                            propertyIsSelected: propertyIsSelected,
                            propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                            portTapAction: onPortTap) { outputViewModel, labelView in
            HStack {
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
                                   isGroupNodeKind: !nodeKind.isGroup,
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
        self.rowViewModel.id.portType
    }

//    @MainActor
//    var hasIncomingEdge: Bool {
//        self.rowData.upstreamOutputObserver.isDefined
//    }

    var nodeIO: NodeIO {
        NodeRowObserverType.nodeIOType
    }
    
    var isGroup: Bool {
        self.rowObserver.nodeDelegate?.kind.isGroup ?? false
    }
    
//    var nodeDelegate: NodeDelegate? {
//        let isSplitterRowAndInvisible = isGroup && rowObserver.nodeDelegate?.id != self.node.nodeDelegate?.id
//
//        // Use passed-in group node so we can obtain view-pertinent information for splitters.
//        // Fixes issue where output splitters use wrong node delegate.
//        if isSplitterRowAndInvisible {
//            return self.node.nodeDelegate
//        }
//        
//        return rowObserver.nodeDelegate
//    }

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

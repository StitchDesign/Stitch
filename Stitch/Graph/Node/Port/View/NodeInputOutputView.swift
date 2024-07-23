//
//  NodeInputView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

// TODO: revisit this when we're able to add LayerNodes with outputs to the graph again
struct AddLayerPropertyToGraphButton: View {
    let propertyIsSelected: Bool
    let coordinate: NodeIOCoordinate
    
    var nodeId: NodeId {
        coordinate.nodeId
    }
    
    var body: some View {
        Image(systemName: "plus.circle")
            .resizable()
            .frame(width: 15, height: 15)
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
            .opacity(propertyIsSelected ? 1 : 0)
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
        HStack(spacing: NODE_COMMON_SPACING) {
            if forPropertySidebar {
                AddLayerPropertyToGraphButton(propertyIsSelected: propertyIsSelected,
                                              coordinate: self.rowObserver.id)
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
        
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: InputFieldViewModel,
                        isMultiField: Bool) -> some View {
        InputValueEntry(graph: graph,
                        rowViewModel: rowData,
                        viewModel: portViewModel,
                        rowObserverId: rowObserver.id,
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
                
                let isPaddingLayerInputRow = rowData.rowDelegate?.id.keyPath == .padding
                let hidePaddingFieldsOnPropertySidebar = isPaddingLayerInputRow && forPropertySidebar
                
                if hidePaddingFieldsOnPropertySidebar {
                    PaddingReadOnlyView(rowObserver: rowObserver,
                                        rowData: rowData,
                                        labelView: labelView)
                    
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
            }
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

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
            return layerInputType.layerInput != SHADOW_FLYOUT_LAYER_INPUT_PROXY
        case .layerOutput:
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
            JumpToLayerPropertyOnGraphButton(canvasItemId: canvasItemId,
                                             isRowSelected: isRowSelected)
        } else {
            AddLayerPropertyToGraphButton(coordinate: coordinate,
                                          isRowSelected: isRowSelected)
                .opacity(showAddLayerPropertyButton ? 1 : 0)
                .animation(.default, value: showAddLayerPropertyButton)
        }
    }
}

// TODO: revisit this when we're able to add LayerNodes with outputs to the graph again
struct AddLayerPropertyToGraphButton: View {
    
    @Environment(\.appTheme) var theme
        
    let coordinate: NodeIOCoordinate
    let isRowSelected: Bool
    
    var nodeId: NodeId {
        coordinate.nodeId
    }
    
    var body: some View {
        Image(systemName: "plus.circle")
            .resizable()
            .foregroundColor(isRowSelected ? theme.fontColor : .primary)
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
    @Environment(\.appTheme) var theme
    
    let canvasItemId: CanvasItemId
    let isRowSelected: Bool
        
    var body: some View {
        // TODO: use a button ?
        Image(systemName: "scope")
            .resizable()
            .foregroundColor(isRowSelected ? theme.fontColor : .primary)
            .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH,
                   height: LAYER_INSPECTOR_ROW_ICON_LENGTH)
            .onTapGesture {
                dispatch(JumpToCanvasItem(id: canvasItemId))
            }
    }
}

//struct NodeInputOutputView<NodeRowObserverType: NodeRowObserver,
//                           FieldsView: View>: View {
//    typealias NodeRowType = NodeRowObserverType.RowViewModelType
//    
//    @State private var showPopover: Bool = false
//    
//    @Bindable var graph: GraphState
//    
////    @Bindable var rowObserver: NodeRowObserverType
////    @Bindable var rowData: NodeRowType
//    
//    let isGroupNode: Bool
//    
//    let label: String
//    let portId: Int
//    let canvasItemId: CanvasItemId?
//    
//    let forPropertySidebar: Bool
//    let propertyIsSelected: Bool
//    
//    @ViewBuilder var fieldsView: (NodeRowType, LabelDisplayView) -> FieldsView
//    
//    @MainActor
//    private var graphUI: GraphUIState {
//        self.graph.graphUI
//    }
//    
////    @MainActor
////    var label: String {
////        if isGroupNode {
////            return rowObserver.nodeDelegate?.displayTitle ?? ""
////        }
////        
////        return self.rowObserver.label(forPropertySidebar)
////    }
//    
////    var isGroupNode: Bool {
////        self.rowData.nodeDelegate?.kind.isGroup ?? false
////    } 
//    
//    var body: some View {
//        // Fields and port ordering depending on input/output
//        self.fieldsView(rowData, labelView)
//        
////        NodeInputOutputView
//        // Don't specify height for layer inspector property row, so that multifields can be shown vertically
//        
//        // NO LONGER RELEVANT SINCE FIELDS NO LONGER STACKED VERTICALLY?
////            .frame(height: forPropertySidebar ? nil : NODE_ROW_HEIGHT)
//        
//        // ALSO NO LONGER RELEVANT
//            .padding([.top, .bottom], forPropertySidebar ? 8 : 0)
//  
//        // Now handled in `ActiveIndexChangedAction`
////            .onChange(of: self.graphUI.activeIndex) {
////                let oldViewValue = self.rowData.activeValue
////                let newViewValue = self.rowObserver.activeValue
////                self.rowData.activeValueChanged(oldValue: oldViewValue,
////                                                newValue: newViewValue)
////            }
//        
//        // MOVED TO NodeOutputView
//        //
////            .modifier(EdgeEditModeViewModifier(graphState: graph,
////                                               portId: portId, //rowData.id.portId,
////                                               canvasItemId: canvasItemId, //self.rowData.canvasItemDelegate?.id,
////                                               nodeIOType: NodeRowType.nodeIO,
////                                               forPropertySidebar: forPropertySidebar))
//    }
//    
//    @ViewBuilder @MainActor
//    var labelView: LabelDisplayView {
//        LabelDisplayView(label: label,
//                         isLeftAligned: false,
//                         fontColor: STITCH_FONT_GRAY_COLOR,
//                         isSelectedInspectorRow: propertyIsSelected)
//    }
//}



/*
 Patch node input of Point4D = one node row observer becomes 4 fields
 
 Layer node input of Size = one node row observer becomes 1 single field
 */
struct NodeInputView: View {
    
    @Environment(\.appTheme) var theme
    
    @State private var showPopover: Bool = false
    
    @Bindable var graph: GraphState
    
    let nodeId: NodeId
    let nodeKind: NodeKind
    let hasIncomingEdge: Bool
    
    // What does this really mean
    let rowObserverId: NodeIOCoordinate
    
//    @Bindable var rowObserver: InputNodeRowObserver
//    @Bindable var rowData: InputNodeRowObserver.RowViewModelType
    
    // Only for inputs on the canvas; never for inputs on the
    // Ah, but the @Bindables can't be optional ?
    // that's okay -- wrap them in data
//    @Bindable var rowObserver: InputNodeRowObserver
//    @Bindable var rowData: InputNodeRowObserver.RowViewModelType
    
    // ONLY for port-view
    let rowObserver: InputNodeRowObserver?
    let rowData: InputNodeRowObserver.RowViewModelType?
        
    let fieldValueTypes: [FieldGroupTypeViewModel<InputNodeRowViewModel.FieldType>]
    // rowData.fieldValueTypes
    
    // This is for the inspector-row, so
    let inputLayerNodeRowData: LayerInputObserver?
    
    let forPropertySidebar: Bool
    let propertyIsSelected: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isCanvasItemSelected: Bool

    var isGroupNodeKind: Bool {
        nodeKind.isGroup
    }
    // rowObserver.nodeDelegate?.kind.isGroup ?? false,
    
    // NOTE: only for specific for inspector row cases
    let layerInput: LayerInputPort?
    
    var label: String //
    
    // @MainActor
   //    var label: String {
   //        if isGroupNode {
   //            return rowObserver.nodeDelegate?.displayTitle ?? ""
   //        }
   //
   //        // this will need to change for packed vs unpacked
   //        return self.rowObserver.label(forPropertySidebar)
   //    }
    
    
    var forFlyout: Bool = false
    
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
//    var nodeId: NodeId {
//        self.rowObserver.id.nodeId
//    }
    
    // pass in instead of accessing via nodeDelegate
//    @MainActor
//    var nodeKind: NodeKind {
//        self.rowObserver.nodeDelegate?.kind ?? .patch(.splitter)
//    }
        
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: InputFieldViewModel,
                        isMultiField: Bool) -> InputValueEntry {
        InputValueEntry(graph: graph,
//                        rowViewModel: rowData,
                        viewModel: portViewModel, 
                        inputLayerNodeRowData: inputLayerNodeRowData,
                        rowObserverId: rowObserverId, //rowObserver.id,
                        nodeKind: nodeKind,
                        isCanvasItemSelected: isCanvasItemSelected,
                        hasIncomingEdge: hasIncomingEdge,  //rowObserver.upstreamOutputObserver.isDefined,
                        forPropertySidebar: forPropertySidebar,
                        propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                        isFieldInMultifieldInput: isMultiField,
                        isForFlyout: forFlyout,
                        isSelectedInspectorRow: propertyIsSelected)
    }
    
//    var layerInput: LayerInputPort? {
//        rowData.rowDelegate?.id.keyPath?.layerInput
//    }
    
    var body: some View {
//        NodeInputOutputView(graph: graph,
////                            rowObserver: rowObserver,
////                            rowData: rowData,
//                            forPropertySidebar: forPropertySidebar,
////                            propertyIsSelected: propertyIsSelected) { (inputViewModel: NodeRowType, labelView: LabelDisplayView) in
//                            propertyIsSelected: propertyIsSelected) { (inputViewModel: NodeRowType) in
           
            // For multifields, want the overall label to sit at top of fields' VStack.
            // For single fields, want to the overall label t
            HStack(alignment: hStackAlignment) {
                
                // Alternatively, pass `NodeRowPortView` as a closure like we do with ValueEntry view etc.?
                if !forPropertySidebar,
                   let rowObserver = rowObserver,
                   let rowData = rowData {
                    NodeRowPortView(graph: graph,
                                    rowObserver: rowObserver,
                                    rowViewModel: rowData,
                                    showPopover: $showPopover)
                }
                
                
                // This is a special condition
                let isShadowLayerInputRow = self.layerInput == SHADOW_FLYOUT_LAYER_INPUT_PROXY
                
                if isShadowLayerInputRow, forPropertySidebar, !forFlyout {
                    HStack {
                        StitchTextView(string: "Shadow",
                                       fontColor: propertyIsSelected ? theme.fontColor : STITCH_FONT_GRAY_COLOR)
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
                    
                    if forPropertySidebar {
                        Spacer()
                    }
                    
//                    let fieldValueTypes: [FieldGroupTypeViewModel<InputNodeRowViewModel.FieldType>] = rowData.fieldValueTypes
                    
                    FieldsListView<InputNodeRowViewModel, InputValueEntry>(
                        graph: graph,
                        //                                   rowViewModel: rowData,
                        fieldValueTypes: fieldValueTypes, // rowViewModel.fieldValueTypes
                        nodeId: nodeId,
                        isGroupNodeKind: isGroupNodeKind, //rowObserver.nodeDelegate?.kind.isGroup ?? false,
                        forPropertySidebar: forPropertySidebar,
                        propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                        valueEntryView: valueEntryView)
                }
            } // HStack
//        }
    }
        
    @ViewBuilder @MainActor
    var labelView: LabelDisplayView {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: propertyIsSelected)
    }
    
    // Not needed anymore?
    var hStackAlignment: VerticalAlignment {
        let isMultiField = (fieldValueTypes.first?.fieldObservers.count ?? 0) > 1
        return (forPropertySidebar && isMultiField) ? .firstTextBaseline : .center
    }
    
//    var isMultiField: Bool {
////        (self.rowData.fieldValueTypes.first?.fieldObservers.count ?? 0) > 1
//        (fieldValueTypes.first?.fieldObservers.count ?? 0) > 1
//    }
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
    
    
    var label: String //
    
    // @MainActor
   //    var label: String {
   //        if isGroupNode {
   //            return rowObserver.nodeDelegate?.displayTitle ?? ""
   //        }
   //
   //        // this will need to change for packed vs unpacked
   //        return self.rowObserver.label(forPropertySidebar)
   //    }
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
    var nodeId: NodeId {
        self.rowObserver.id.nodeId
    }
    
    @MainActor
    var nodeKind: NodeKind {
        self.rowObserver.nodeDelegate?.kind ?? .patch(.splitter)
    }
    
    @MainActor
    var isSplitter: Bool {
        self.nodeKind == .patch(.splitter)
    }
        
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: OutputFieldViewModel,
                        isMultiField: Bool) -> OutputValueEntry {
        OutputValueEntry(graph: graph,
//                         rowViewModel: rowData,
                         viewModel: portViewModel,
                         coordinate: rowObserver.id,
                         isMultiField: isMultiField,
                         nodeKind: nodeKind,
                         isCanvasItemSelected: isCanvasItemSelected,
                         forPropertySidebar: forPropertySidebar,
                         propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                         isSelectedInspectorRow: propertyIsSelected)
    }
    
    var body: some View {
//        NodeInputOutputView(graph: graph,
//                            rowObserver: rowObserver,
//                            rowData: rowData,
//                            forPropertySidebar: forPropertySidebar,
//                            propertyIsSelected: propertyIsSelected) { outputViewModel, labelView in
            HStack(alignment: forPropertySidebar ? .firstTextBaseline: .center) {
                // Property sidebar always shows labels on left side, never right
                if forPropertySidebar {
                    labelView
                    
                    // TODO: fields in layer-inspector flush with right screen edge?
                    //                    Spacer()
                }
                
                // Hide outputs for value node
                if !isSplitter {
                    let fieldValueTypes: [FieldGroupTypeViewModel<OutputNodeRowViewModel.FieldType>] = rowData.fieldValueTypes
                    
                    FieldsListView<OutputNodeRowViewModel, OutputValueEntry>(graph: graph,
//                                   rowViewModel: rowData,
                                   fieldValueTypes: fieldValueTypes,
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
            } // HStack
            
            // Only for outputs
            .modifier(EdgeEditModeViewModifier(graphState: graph,
                                               portId: rowData.id.portId,
                                               canvasItemId: self.rowData.canvasItemDelegate?.id,
                                               forPropertySidebar: forPropertySidebar))
//        }
    }
    
    @ViewBuilder @MainActor
    var labelView: LabelDisplayView {
        LabelDisplayView(label: label,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: propertyIsSelected)
    }
}

// or should new protocol be taken here?
// i.e. `row view model` should replaced by a protocol that is just
struct FieldsListView<PortType, ValueEntryView>: View where PortType: NodeRowViewModel, ValueEntryView: View {
    @Bindable var graph: GraphState
    
    // make more generic?
    // currently we pass on the exact view model
//    @Bindable var rowViewModel: PortType // e.g. InputNodeRowViewModel
    var fieldValueTypes: [FieldGroupTypeViewModel<PortType.FieldType>]
    
    let nodeId: NodeId
    let isGroupNodeKind: Bool
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    @ViewBuilder var valueEntryView: (PortType.FieldType, Bool) -> ValueEntryView
    
    var body: some View {
//        ForEach(rowViewModel.fieldValueTypes) { (fieldGroupViewModel: FieldGroupTypeViewModel<PortType.FieldType>) in
        
        // Ah, for an unpacked layer input, we pass in multiple `fieldGroupViewModel`s, each of which has a single `fieldObserver` ?
        // And for packed layer input, we pass in a single `fieldGroupViewModel`, which has multiple `fieldObserver`s ?
        // `isMultifield` can be passed down at the top-level
        
        let multipleFieldGroups = fieldValueTypes.count > 1
        
        ForEach(fieldValueTypes) { (fieldGroupViewModel: FieldGroupTypeViewModel<PortType.FieldType>) in
            
            let multipleFieldsPerGroup = fieldGroupViewModel.fieldObservers.count > 1
            
            // In non-property-sidebar cases, an input
            
            // if we're in the inspector-row or flyout-row, we are
            
            // i.e. don't need to think about packed vs unpacked
            let isMultiField = forPropertySidebar ?  (multipleFieldGroups || multipleFieldsPerGroup) : fieldGroupViewModel.fieldObservers.count > 1
            
//            let isMultiField = fieldGroupViewModel.fieldObservers.count > 1
            
            logInView("isMultiField: \(isMultiField)")
            
            NodeFieldsView(graph: graph,
                           fieldGroupViewModel: fieldGroupViewModel,
                           nodeId: nodeId,
                           isGroupNodeKind: isGroupNodeKind,
                           isMultiField: isMultiField,
                           forPropertySidebar: forPropertySidebar,
                           propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                           valueEntryView: valueEntryView)
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
    
    // should be passed down as a param
    @MainActor
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

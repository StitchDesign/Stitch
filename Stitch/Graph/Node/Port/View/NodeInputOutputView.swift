//
//  NodeInputView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

struct LayerInspectorRowButton: View {
    
    @Environment(\.appTheme) var theme
    
    let layerInputObserver: LayerInputObserver
    let layerInspectorRowId: LayerInspectorRowId
    let coordinate: NodeIOCoordinate
    let canvasItemId: CanvasItemId?
    let isPortSelected: Bool
    let isHovered: Bool
    
    @MainActor
    var isWholeInputWithAtleastOneFieldAlreadyOnCanvas: Bool {
        if case let .layerInput(layerInputType) = layerInspectorRowId,
           layerInputType.portType == .packed,
           layerInputObserver.observerMode.isUnpacked,
           !layerInputObserver.getAllCanvasObservers().isEmpty {
            log("LayerInspectorRowButton:isWholeInputWithAtleastOneFieldAlreadyOnCanvas")
            return true
        }
        
        return false
    }
    
    @MainActor
    var canBeAddedToCanvas: Bool {
        
        // If this is a button for a whole input,
        // and then input already has a field on the canvas,
        // then we cannot add the whole input to the canvas
        if isWholeInputWithAtleastOneFieldAlreadyOnCanvas {
            return false
        }
        
        switch layerInspectorRowId {
        case .layerInput(let layerInputType):
            return layerInputType.layerInput != SHADOW_FLYOUT_LAYER_INPUT_PROXY
        case .layerOutput:
            return true
        }
    }

    @MainActor
    var showAddLayerPropertyButton: Bool {
        if canvasItemId.isDefined {
            return false
        }
        
        if isHovered {
            return true
        }
        
        if canBeAddedToCanvas, isPortSelected {
            return true
        }
        
        return false
    }
    
    @MainActor
    var showButton: Bool {
        if canvasItemId.isDefined {
            return true
        }
        
        if isWholeInputWithAtleastOneFieldAlreadyOnCanvas {
            return true
        }
        
        if isHovered {
            return true
        }
        
        if canBeAddedToCanvas, isPortSelected {
            return true
        }
        
        return false
    }
    
    @MainActor
    var imageString: String {
        if canvasItemId.isDefined {
            return "scope"
        } else if isWholeInputWithAtleastOneFieldAlreadyOnCanvas {
            return "circle.fill"
        } else {
            return "plus.circle"
        }
    }
        
    var body: some View {
        
//        button(imageString: imageString) {
//            
//            let nodeId = coordinate.nodeId
//            
//            // If we're already on the canvas, jump to that canvas item
//            if let canvasItemId = canvasItemId {
//                dispatch(JumpToCanvasItem(id: canvasItemId))
//            } 
//            
//            // Else we're adding an input (whole or field) or an output to the canvas
//            else if let layerInput = coordinate.keyPath {
//                dispatch(LayerInputAddedToGraph(
//                    nodeId: nodeId,
//                    coordinate: layerInput))
//            } else if let portId = coordinate.portId {
//                dispatch(LayerOutputAddedToGraph(nodeId: nodeId,
//                                                 portId: portId))
//            }
//        }
//        // Shrink down the dot view
//        .scaleEffect(isWholeInputWithAtleastOneFieldAlreadyOnCanvas ? 0.5 : 1)
//        
//        // Only show the dot / plus button if we're hovering or row is selected or ...
//        .opacity(showButton ? 1 : 0)
//        
//        .animation(.default, value: showButton)
        
        
        
        if let canvasItemId = canvasItemId {
            button(imageString: "scope") {
                dispatch(JumpToCanvasItem(id: canvasItemId))
            }
        } else {
            button(imageString: isWholeInputWithAtleastOneFieldAlreadyOnCanvas ? "circle.fill" : "plus.circle") {
                let nodeId = coordinate.nodeId
                if let layerInput = coordinate.keyPath {
                    
                    switch layerInput.portType {
                    
                    case .packed:
                        dispatch(LayerInputAddedToGraph(
                            nodeId: nodeId,
                            coordinate: layerInput))
                        
                    case .unpacked(let unpackedPortType):
                        dispatch(LayerInputFieldAddedToGraph(
                            layerInput: layerInput.layerInput, 
                            nodeId: nodeId,
                            fieldIndex: unpackedPortType.rawValue))
                    }
                    
                    
                } else if let portId = coordinate.portId {
                    dispatch(LayerOutputAddedToGraph(nodeId: nodeId,
                                                     portId: portId))
                }
            }
            
            // Shrink down the dot view
            .scaleEffect(isWholeInputWithAtleastOneFieldAlreadyOnCanvas ? 0.5 : 1)
            
            // Only show the dot / plus button if we're hovering or row is selected or ...
            .opacity((isWholeInputWithAtleastOneFieldAlreadyOnCanvas || showAddLayerPropertyButton) ? 1 : 0)
            
            .animation(.default,
                       value: (isWholeInputWithAtleastOneFieldAlreadyOnCanvas || showAddLayerPropertyButton))
        }
    }
    
    @MainActor
    func button(imageString: String,
                onTap: @escaping () -> Void) -> some View {
        Image(systemName: imageString)
            .resizable()
            .foregroundColor(isPortSelected ? theme.fontColor : .primary)
            .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH,
                   height: LAYER_INSPECTOR_ROW_ICON_LENGTH) // per Figma
            .onTapGesture {
                onTap()
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
    
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: InputFieldViewModel,
                        isMultiField: Bool) -> InputValueEntry {
        InputValueEntry(graph: graph,
                        viewModel: portViewModel,
                        inputLayerNodeRowData: inputLayerNodeRowData,
                        rowObserverId: rowObserverId,
                        nodeKind: nodeKind,
                        isCanvasItemSelected: isCanvasItemSelected,
                        hasIncomingEdge: hasIncomingEdge,
                        forPropertySidebar: forPropertySidebar,
                        propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                        isFieldInMultifieldInput: isMultiField,
                        isForFlyout: forFlyout,
                        isSelectedInspectorRow: propertyIsSelected)
    }
    
    var body: some View {
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
                
                FieldsListView<InputNodeRowViewModel, InputValueEntry>(
                    graph: graph,
                    fieldValueTypes: fieldValueTypes,
                    nodeId: nodeId,
                    isGroupNodeKind: isGroupNodeKind,
                    forPropertySidebar: forPropertySidebar,
                    propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                    valueEntryView: valueEntryView)
            }
        } // HStack
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
    let label: String
    
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
        HStack(alignment: forPropertySidebar ? .firstTextBaseline: .center) {
            // Property sidebar always shows labels on left side, never right
            if forPropertySidebar {
                labelView
            }
            
            // Hide outputs for value node
            if !isSplitter {
                let fieldValueTypes: [FieldGroupTypeViewModel<OutputNodeRowViewModel.FieldType>] = rowData.fieldValueTypes
                
                FieldsListView<OutputNodeRowViewModel, OutputValueEntry>(
                    graph: graph,
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
        
        .modifier(EdgeEditModeOutputViewModifier(
            graphState: graph,
            portId: rowData.id.portId,
            canvasItemId: self.rowData.canvasItemDelegate?.id,
            forPropertySidebar: forPropertySidebar))
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

    var fieldValueTypes: [FieldGroupTypeViewModel<PortType.FieldType>]
    let nodeId: NodeId
    let isGroupNodeKind: Bool
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    @ViewBuilder var valueEntryView: (PortType.FieldType, Bool) -> ValueEntryView
    
    var body: some View {
        // Ah, for an unpacked layer input, we pass in multiple `fieldGroupViewModel`s, each of which has a single `fieldObserver` ?
        // And for packed layer input, we pass in a single `fieldGroupViewModel`, which has multiple `fieldObserver`s ?
        // `isMultifield` can be passed down at the top-level
        
        let multipleFieldGroups = fieldValueTypes.count > 1
        
        ForEach(fieldValueTypes) { (fieldGroupViewModel: FieldGroupTypeViewModel<PortType.FieldType>) in
            
            let multipleFieldsPerGroup = fieldGroupViewModel.fieldObservers.count > 1
            
            // Note: "multifield" is more complicated for layer inputs, since `fieldObservers.count` is now inaccurate
            let isMultiField = forPropertySidebar ?  (multipleFieldGroups || multipleFieldsPerGroup) : fieldGroupViewModel.fieldObservers.count > 1
                                    
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

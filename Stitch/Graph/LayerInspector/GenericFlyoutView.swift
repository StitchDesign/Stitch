//
//  PaddingFlyoutView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/15/24.
//

import SwiftUI
import StitchSchemaKit

extension Color {
    static let SWIFTUI_LIST_BACKGROUND_COLOR = Color(uiColor: .secondarySystemBackground)
}

struct GenericFlyoutView: View {
    
    static let DEFAULT_FLYOUT_WIDTH = 256.0 // Per Figma
    
    // Note: added later, because a static height is required for UIKitWrapper (key press listening); may be able to replace
    //    static let PADDING_FLYOUT_HEIGHT = 170.0 // Calculated by Figma
    @State var height: CGFloat? = nil
    
    @Bindable var graph: GraphState
    
    // Don't actually have access to this if the layer input is e.g. packed instead of unpacked ?
    // or we can always access the _packed data ?
//    let inputRowViewModel: InputNodeRowViewModel
    
    let inputLayerNodeRowData: LayerInputObserver // non-nil, because flyouts are always for inspector inputs
    let layer: Layer
    var hasIncomingEdge: Bool = false
    let layerInput: LayerInputPort
    
    let nodeId: NodeId
    let nodeKind: NodeKind
    
    let fieldValueTypes: [FieldGroupTypeViewModel<InputNodeRowViewModel.FieldType>]
        
    var body: some View {
        
        VStack(alignment: .leading) {
            // TODO: need better padding here; but confounding factor is UIKitWrapper
            FlyoutHeader(flyoutTitle: layerInput.label(true))
            
            // TODO: better keypress listening situation; want to define a keypress press once in the view hierarchy, not multiple places etc.
            // Note: keypress listener needed for TAB, but UIKitWrapper messes up view's height if specific height not provided
            
            // TODO: UIKitWrapper adds a bit of padding at the bottom?
            //            UIKitWrapper(ignoresKeyCommands: false,
            //                         name: "PaddingFlyout") {
            // TODO: finalize this logic once fields are in?
            flyoutRows
            //            }
        }
        .padding()
        .background(Color.WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE)
        .cornerRadius(8)
        .frame(width: Self.DEFAULT_FLYOUT_WIDTH,
               height: self.height)
        .background {
            // TODO: this isn't quite accurate; read-height doesn't seem tall enough?
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .named(NodesView.coordinateNameSpace)),
                              initial: true) { oldValue, newValue in
                        log("GenericFlyout size: \(newValue.size)")
                        dispatch(UpdateFlyoutSize(size: newValue.size))
                    }
            }
        }
    }
    
    @State var selectedFlyoutRow: Int? = nil
        
    // TODO: just use `NodeInputView` here ?
    @ViewBuilder @MainActor
    var flyoutRows: some View {
        // Assumes: all flyouts have a single row which contains multiple fields
        
        // Can't just use NodeInputView, since we need to add a button

        FieldsListView<InputNodeRowViewModel, GenericFlyoutRowView>(
            graph: graph,
            fieldValueTypes: fieldValueTypes,
            nodeId: nodeId,
            isGroupNodeKind: false,
            forPropertySidebar: true,
            // fix this?
            propertyIsAlreadyOnGraph: false) { inputFieldViewModel, isMultifield in
                
//                Text("FlyoutRow")
                
                let fieldIndex = inputFieldViewModel.fieldIndex
                let isSelectedRow = self.selectedFlyoutRow == fieldIndex
                
                  GenericFlyoutRowView(
                    graph: graph,
                    viewModel: inputFieldViewModel,
                    // coordinate: inputF // inputRowViewModel.rowDelegate?.id,
                    inputLayerNodeRowData: inputLayerNodeRowData,
                    layerInput: layerInput,
                    nodeId: nodeId,
                    fieldIndex: fieldIndex,
                    isMultifield: isMultifield,
                    nodeKind: nodeKind
//                     ,
//                    isSelectedRow: isSelectedRow
                  )
                
//                GenericFlyoutRowView(layerInput: layerInput,
//                                     nodeId: nodeId,
//                                     fieldIndex: fieldIndex,
//                                     isSelectedRow: isSelectedRow)
            
//            if let coordinate = inputRowViewModel.rowDelegate?.id {
//                
//                let fieldIndex = inputFieldViewModel.fieldIndex
//                let isSelectedRow = self.selectedFlyoutRow == fieldIndex
//                
//                HStack {
//                    // TODO: consolidate with `LayerInspectorRowButton`
//                    // TODO: Figma UI: field on canvas
//                    Image(systemName: "plus.circle")
//                        .resizable()
//                        .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH,
//                               height: LAYER_INSPECTOR_ROW_ICON_LENGTH)
//                        .onTapGesture {
//                            log("will add field to canvas")
//                            dispatch(LayerInputFieldAddedToGraph(
//                                layerInput: layerInput,
//                                nodeId: nodeId,
//                                fieldIndex: fieldIndex))
//                        }
//                        .opacity(isSelectedRow ? 1 : 0)
//                    
////                    // For a single field
////                    InputValueEntry(graph: graph,
////                                    rowViewModel: inputRowViewModel,
////                                    viewModel: inputFieldViewModel,
////                                    inputLayerNodeRowData: inputLayerNodeRowData,
////                                    rowObserverId: coordinate,
////                                    nodeKind: .layer(layer),
////                                    isCanvasItemSelected: false,
////                                    hasIncomingEdge: hasIncomingEdge, // always false?
////                                    forPropertySidebar: true,
////                                    // TODO: Figma UI: field on canvas
////                                    propertyIsAlreadyOnGraph: false, // Not relevant?
////                                    isFieldInMultifieldInput: isMultifield,
////                                    isForFlyout: true,
////                                    // False for now, until individual fields can be added to the graph
////                                    isSelectedInspectorRow: false)
////                    .onTapGesture {
////                        log("flyout: tapped field row \(fieldIndex)")
////                        self.selectedFlyoutRow = fieldIndex
////                    }
//                }
//            } // if let
//            
//            else {
//                FatalErrorIfDebugView()
//            }
        }
        
        
//        FieldsListView(graph: graph,
//                       rowViewModel: inputRowViewModel,
//                       nodeId: inputRowViewModel.id.nodeId,
//                       isGroupNodeKind: inputRowViewModel.nodeKind.isGroup,
//                       forPropertySidebar: true,
//                       // TODO: fix
//                       propertyIsAlreadyOnGraph: false) { inputFieldViewModel, isMultiField in
//            
//            if let coordinate = inputRowViewModel.rowDelegate?.id {
//                
//                let fieldIndex = inputFieldViewModel.fieldIndex
//                let isSelectedRow = self.selectedFlyoutRow == fieldIndex
//                
//                HStack {
//                    // TODO: consolidate with `LayerInspectorRowButton`
//                    // TODO: Figma UI: field on canvas
//                    Image(systemName: "plus.circle")
//                        .resizable()
//                        .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH,
//                               height: LAYER_INSPECTOR_ROW_ICON_LENGTH)
//                        .onTapGesture {
//                            log("will add field to canvas")
//                            dispatch(LayerInputFieldAddedToGraph(
//                                layerInput: layerInput,
//                                nodeId: nodeId,
//                                fieldIndex: fieldIndex))
//                        }
//                        .opacity(isSelectedRow ? 1 : 0)
//                    
//                    // For a single field
//                    InputValueEntry(graph: graph,
//                                    rowViewModel: inputRowViewModel,
//                                    viewModel: inputFieldViewModel,
//                                    inputLayerNodeRowData: inputLayerNodeRowData,
//                                    rowObserverId: coordinate,
//                                    nodeKind: .layer(layer),
//                                    isCanvasItemSelected: false,
//                                    hasIncomingEdge: hasIncomingEdge, // always false?
//                                    forPropertySidebar: true,
//                                    // TODO: Figma UI: field on canvas
//                                    propertyIsAlreadyOnGraph: false, // Not relevant?
//                                    isFieldInMultifieldInput: isMultiField,
//                                    isForFlyout: true,
//                                    // False for now, until individual fields can be added to the graph
//                                    isSelectedInspectorRow: false)
//                    .onTapGesture {
//                        log("flyout: tapped field row \(fieldIndex)")
//                        self.selectedFlyoutRow = fieldIndex
//                    }
//                }
//            } // if let
//            
//            else {
//                FatalErrorIfDebugView()
//            }
//        } // FieldsListView
        
    }
}

struct GenericFlyoutRowView: View {
    
    @Bindable var graph: GraphState
    let viewModel: InputFieldViewModel
    
//    let coordinate: NodeIOCoordinate?
    
    let inputLayerNodeRowData: LayerInputObserver?
    
    let layerInput: LayerInputPort
    let nodeId: NodeId
    let fieldIndex: Int
    
    let isMultifield: Bool
    let nodeKind: NodeKind
    
//    let isSelectedRow: Bool
    @State var isSelectedRow: Bool = false
    
    var body: some View {
        //        Text("GenericFlyoutRowView")
        
        if let coordinate = viewModel.rowDelegate?.id {
            HStack {
                Image(systemName: "plus.circle")
                    .resizable()
                    .frame(width: LAYER_INSPECTOR_ROW_ICON_LENGTH,
                           height: LAYER_INSPECTOR_ROW_ICON_LENGTH)
                    .onTapGesture {
                        log("will add field to canvas")
                        dispatch(LayerInputFieldAddedToGraph(
                            layerInput: layerInput,
                            nodeId: nodeId,
                            fieldIndex: fieldIndex))
                    }
                    .opacity(isSelectedRow ? 1 : 0)
                
                InputValueEntry(graph: graph,
                                viewModel: viewModel,
                                inputLayerNodeRowData: inputLayerNodeRowData,
                                rowObserverId: coordinate,
                                nodeKind: nodeKind,
                                isCanvasItemSelected: false,
                                hasIncomingEdge: false,
                                forPropertySidebar: true,
                                propertyIsAlreadyOnGraph: false, // fix
                                isFieldInMultifieldInput: isMultifield,
                                isForFlyout: true,
                                isSelectedInspectorRow: false)
            } // HStack
            .border(.green)
            .contentShape(Rectangle())
            .border(.red)
            .onTapGesture {
                log("flyout: tapped field row \(fieldIndex)")
//                self.selectedFlyoutRow = fieldIndex
                self.isSelectedRow.toggle()
            }
            
        } else {
            FatalErrorIfDebugView()
        }
    }
}

struct FatalErrorIfDebugView: View {
    var body: some View {
        Color.clear
            .onAppear {
                fatalErrorIfDebug()
            }
    }
}

struct LayerInputFieldAddedToGraph: GraphEventWithResponse {
    
    //    let layerInput: LayerInputType
    let layerInput: LayerInputPort
    let nodeId: NodeId
    let fieldIndex: Int
    
    func handle(state: GraphState) -> GraphResponse {
        
        guard let node = state.getNode(nodeId),
              let layerNode = node.layerNode else {
            return .noChange
        }
        
//        fatalErrorIfDebug()
//        return .noChange
        
        // How to get the `LayerInputObserver`, given a `LayerInputType` or `LayerInputPort` ?
        // Note: `layerNode[keyPath: layerInput.layerNodeKeyPath]` retrieves `InputLayerNodeRowData`
        let portObserver: LayerInputObserver = layerNode[keyPath: layerInput.layerNodeKeyPath]
        
        // Confusing: this is for a specific field but the type is called `InputLayerNodeRowData` ?
        //        let fieldObserver: InputLayerNodeRowData? = 
        portObserver._unpackedData.allPorts[safe: fieldIndex]
        
        if let unpackedPort: InputLayerNodeRowData = portObserver._unpackedData.allPorts[safe: fieldIndex] {
            
            let parentGroupNodeId = portObserver.graphDelegate?.groupNodeFocused
            
            var unpackSchema = unpackedPort.createSchema()
            unpackSchema.canvasItem = .init(position: state.newLayerPropertyLocation,
                                            zIndex: state.highestZIndex + 1,
                                            parentGroupNodeId: parentGroupNodeId)
            
            // TODO: SEPT 12
            let unpackedPortParentFieldGroupType: FieldGroupType? = nil
            let unpackedPortIndex: Int? = nil
            unpackedPort.update(from: unpackSchema,
                                layerInputType: unpackedPort.id,
                                layerNode: layerNode,
                                nodeId: nodeId,
                                unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                unpackedPortIndex: unpackedPortIndex,
                                nodeDelegate: node)
        }
        
        return .persistenceResponse
    }
}

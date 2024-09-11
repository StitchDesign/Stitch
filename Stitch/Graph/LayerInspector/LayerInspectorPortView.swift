//
//  LayerInspectorPortView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/24.
//

import SwiftUI
import StitchSchemaKit


struct LayerInspectorInputPortView: View {
    @Bindable var portObserver: LayerInputObserver
    @Bindable var graph: GraphState
    
    var body: some View {
        let observerMode = portObserver.observerMode
        
        let layerInputType = LayerInputType(layerInput: portObserver.port,
                                            // Always `.packed` at the inspector-row level
                                            portType: .packed)
        
        let layerProperty: LayerInspectorRowId = .layerInput(layerInputType)
        
        
        // We pass down coordinate because that can be either for an input (added whole input to the graph) or output (added whole output to the graph, i.e. a port id)
        // But now, what `AddLayerPropertyToGraphButton` needs is more like `RowCoordinate = LayerPortCoordinate || OutputCoordinate`
        
        // but canvas item view model needs to know "packed vs unpacked" for its id;
        // so we do need to pass the packed-vs-unpacked information
        
        //
        
        let coordinate: NodeIOCoordinate = .init(
            portType: .keyPath(layerInputType),
            nodeId: portObserver.nodeId)
        
        // When a single field is on the canvas, should we show the "this inspector row is on the canvas" ?
        // Per Origami, no?
        
        // Does this inspector-row (the entire input) have a canvas item?
        let canvasItemId: CanvasItemId? = observerMode.isPacked ? portObserver._packedData.canvasObserver?.id : nil
        
//        // Grab the "parent"/"packed"
//        let inputLayerNodeRowData: LayerInputObserver =
//        let canvasItemId = inputLayerNodeRowData.canvasObserver?.id
        
        Text("Love")
        
        LayerInspectorPortView(
            layerProperty: layerProperty,
            coordinate: coordinate,
            graph: graph,
            canvasItemId: canvasItemId) { propertyRowIsSelected in
                NodeInputView(graph: graph,
                              rowObserver: inputLayerNodeRowData.rowObserver,
                              rowData: inputLayerNodeRowData.inspectorRowViewModel,
                              inputLayerNodeRowData: inputLayerNodeRowData,
                              forPropertySidebar: true,
                              propertyIsSelected: propertyRowIsSelected,
                              propertyIsAlreadyOnGraph: canvasItemId.isDefined,
                              isCanvasItemSelected: false)
            }
        
        
        
//
//
//        // TODO: inspector row ALWAYS shows packed version; individual fields are only shows as rows in the flyout ('flyout row')
//        Group {
//            switch observerMode {
//            case .packed(let inputLayerNodeRowData):
//                let canvasItemId = inputLayerNodeRowData.canvasObserver?.id
//                
//                LayerInspectorPortView(
//                    layerProperty: .layerInput(inputLayerNodeRowData.id),
//                    rowViewModel: inputLayerNodeRowData.inspectorRowViewModel,
//                    rowObserver: inputLayerNodeRowData.rowObserver,
//                    graph: graph,
//                    canvasItemId: canvasItemId) { propertyRowIsSelected in
//                        
//                        NodeInputView(graph: graph,
//                                      rowObserver: inputLayerNodeRowData.rowObserver,
//                                      rowData: inputLayerNodeRowData.inspectorRowViewModel,
//                                      inputLayerNodeRowData: inputLayerNodeRowData,
//                                      forPropertySidebar: true,
//                                      propertyIsSelected: propertyRowIsSelected,
//                                      propertyIsAlreadyOnGraph: canvasItemId.isDefined,
//                                      isCanvasItemSelected: false)
//                    }
//                
//                
//            case .unpacked(let unpackedPortObserver):
//                ForEach(unpackedPortObserver.allPorts) { unpackedPort in
//                    let canvasItemId = unpackedPort.canvasObserver?.id
//                    
//                    LayerInspectorPortView(layerProperty: .layerInput(unpackedPort.id),
//                                           rowViewModel: unpackedPort.inspectorRowViewModel,
//                                           rowObserver: unpackedPort.rowObserver,
//                                           graph: graph,
//                                           canvasItemId: canvasItemId) { propertyRowIsSelected in
//                        NodeInputView(graph: graph,
//                                      rowObserver: unpackedPort.rowObserver,
//                                      rowData: unpackedPort.inspectorRowViewModel,
//                                      inputLayerNodeRowData: nil, // TODO: handle properly
//                                      forPropertySidebar: true,
//                                      propertyIsSelected: propertyRowIsSelected,
//                                      propertyIsAlreadyOnGraph: canvasItemId.isDefined,
//                                      isCanvasItemSelected: false)
//                    }
//                }
//                
//            } // observerMode
//        } // Group
        
        .onChange(of: portObserver.mode) {
            self.portObserver.wasPackModeToggled()
        }
    }
}



struct LayerInspectorOutputPortView: View {
    let outputPortId: Int
    
    @Bindable var rowViewModel: OutputNodeRowViewModel
    @Bindable var rowObserver: OutputNodeRowObserver
    @Bindable var graph: GraphState
    
    let canvasItemId: CanvasItemId?
    
    var body: some View {
        Text("Implement me")
            .onAppear(perform: {
                fatalErrorIfDebug()
            })
        
//        LayerInspectorPortView(layerProperty: .layerOutput(outputPortId),
//                               rowViewModel: rowViewModel,
//                               rowObserver: rowObserver,
//                               graph: graph,
//                               canvasItemId: canvasItemId) { propertyRowIsSelected in
//            NodeOutputView(graph: graph,
//                           rowObserver: rowObserver,
//                           rowData: rowViewModel,
//                           forPropertySidebar: true,
//                           propertyIsSelected: propertyRowIsSelected,
//                           propertyIsAlreadyOnGraph: canvasItemId.isDefined,
//                           isCanvasItemSelected: false)
//        }
    }
}

// spacing between e.g. "add to graph" button (icon) and start of row capsule
let LAYER_INSPECTOR_ROW_SPACING = 8.0

// how big an icon / button is
let LAYER_INSPECTOR_ROW_ICON_LENGTH = 16.0

struct LayerInspectorPortView<RowObserver, RowView>: View where RowObserver: NodeRowObserver, RowView: View {
        
    // input or output
    let layerProperty: LayerInspectorRowId
    
    @Bindable var rowViewModel: RowObserver.RowViewModelType
//    @Bindable var rowObserver: RowObserver
    let coordinate: NodeIOCoordinate
    @Bindable var graph: GraphState
    
    // non-nil = this row is present on canvas
    // NOTE: apparently, the destruction of a weak var reference does NOT trigger a SwiftUI view update; so, avoid using delegates in the UI body.
    let canvasItemId: CanvasItemId?
    
    // Arguments: 1. is row selected
    @ViewBuilder var rowView: (Bool) -> RowView
    
    @State private var isHovered: Bool = false
    
    // Is this property-row selected?
    @MainActor
    var propertyRowIsSelected: Bool {
        graph.graphUI.propertySidebar.selectedProperty == layerProperty
    }
    
    var isOnGraphAlready: Bool {
        canvasItemId.isDefined
    }
    
    var body: some View {
        HStack {
            LayerInspectorRowButton(layerProperty: layerProperty,
//                                    coordinate: rowObserver.id,
                                    coordinate: coordinate,
                                    canvasItemId: canvasItemId,
                                    isRowSelected: propertyRowIsSelected,
                                    isHovered: isHovered)
            
            rowView(propertyRowIsSelected)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(
            top: INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET,
            leading: 0,
            bottom: INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET,
            trailing: 0))
        .onHover(perform: { isHovering in
            self.isHovered = isHovering
        })
        .contentShape(Rectangle())
        .gesture(
            TapGesture().onEnded({ _ in
                log("LayerInspectorPortView tapped")
                if isOnGraphAlready,
                   let canvasItemId = canvasItemId {
//                   let canvasItemId = rowViewModel.canvasItemDelegate?.id {
                    dispatch(JumpToCanvasItem(id: canvasItemId))
                } else {
                    withAnimation {
                        graph.graphUI.layerPropertyTapped(layerProperty)
                    }
                }
            })
        ) // .gesture
    }
}

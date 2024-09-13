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
    let nodeId: NodeId
    
    var body: some View {
        
        let observerMode = portObserver.observerMode
        
        let layerInputType = LayerInputType(layerInput: portObserver.port,
                                            // Always `.packed` at the inspector-row level
                                            portType: .packed)
        
        let layerInspectorRowId: LayerInspectorRowId = .layerInput(layerInputType)
        
        // We pass down coordinate because that can be either for an input (added whole input to the graph) or output (added whole output to the graph, i.e. a port id)
        // But now, what `AddLayerPropertyToGraphButton` needs is more like `RowCoordinate = LayerPortCoordinate || OutputCoordinate`
        
        // but canvas item view model needs to know "packed vs unpacked" for its id;
        // so we do need to pass the packed-vs-unpacked information
        
        let coordinate: NodeIOCoordinate = .init(
            portType: .keyPath(layerInputType),
            nodeId: nodeId)
        
        // When a single field is on the canvas, should we show the "this inspector row is on the canvas" ?
        // Per Origami, no?
        
        // Does this inspector-row (the entire input) have a canvas item?
        let canvasItemId: CanvasItemId? = observerMode.isPacked ? portObserver._packedData.canvasObserver?.id : nil
        
//        // Grab the "parent"/"packed"
//        let inputLayerNodeRowData: LayerInputObserver =
//        let canvasItemId = inputLayerNodeRowData.canvasObserver?.id
                
//        let propertyRowIsSelected = graph.graphUI.propertySidebar.selectedProperty == layerProperty
        
        LayerInspectorPortView(
            layerInspectorRowId: layerInspectorRowId,
            coordinate: coordinate,
            graph: graph,
            canvasItemId: canvasItemId) { propertyRowIsSelected in
                NodeInputView(graph: graph,
//                              nodeId: portObserver.nodeId,
                              nodeId: nodeId,
                              nodeKind: .layer(portObserver.layer),
                              hasIncomingEdge: false, // always false
                              rowObserverId: coordinate,
                              
                              // Only used for PortEntryView, which inspector- and flyout-rows do not use
                              //                              rowObserver: inputLayerNodeRowData.rowObserver,
                              //                              rowData: inputLayerNodeRowData.inspectorRowViewModel,
                              rowObserver: nil,
                              rowData: nil,
                              // Always use the packed
                              fieldValueTypes: portObserver.fieldValueTypes,
                                // portObserver._packedData.inspectorRowViewModel.fieldValueTypes,
                                //[FieldGroupTypeViewModel<InputNodeRowViewModel.FieldType>]
                              inputLayerNodeRowData: portObserver,
                              forPropertySidebar: true,
                              propertyIsSelected: propertyRowIsSelected,
                              propertyIsAlreadyOnGraph: canvasItemId.isDefined,
                              isCanvasItemSelected: false,
                              layerInput: portObserver.port,
                              // Inspector Row always uses the overall input level, never an individual field label
                              // so use the packed label
                              label: portObserver.overallPortLabel(usesShortLabel: true)
                )
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

//struct LayerInspectorPortView<RowObserver, RowView>: View where RowObserver: NodeRowObserver, RowView: View {
struct LayerInspectorPortView<RowView>: View where RowView: View {
        
    // input or output
    let layerInspectorRowId: LayerInspectorRowId
    
//    @Bindable var rowViewModel: RowObserver.RowViewModelType
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
        graph.graphUI.propertySidebar.selectedProperty == layerInspectorRowId
    }
    
    var isOnGraphAlready: Bool {
        canvasItemId.isDefined
    }
    
    var body: some View {
        HStack {
            LayerInspectorRowButton(layerInspectorRowId: layerInspectorRowId,
                                    coordinate: coordinate,
                                    canvasItemId: canvasItemId,
                                    isPortSelected: propertyRowIsSelected,
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
                    dispatch(JumpToCanvasItem(id: canvasItemId))
                } else {
                        graph.graphUI.layerPropertyTapped(layerInspectorRowId)
                }
            })
        ) // .gesture
    }
}

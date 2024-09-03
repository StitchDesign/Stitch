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
        
        Group {
            switch observerMode {
            case .packed(let inputLayerNodeRowData):
                let canvasItemId = inputLayerNodeRowData.canvasObserver?.id
                
                LayerInspectorPortView(
                    layerProperty: .layerInput(inputLayerNodeRowData.id),
                    rowViewModel: inputLayerNodeRowData.inspectorRowViewModel,
                    rowObserver: inputLayerNodeRowData.rowObserver,
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
                // NOTE: attaching even a ZStack around LayerInspectorPortView causes the row's background color to expand to fill whole list row
                // TODO: finalize UI for pack, unpack
                    .overlay(alignment: .topLeading) {
                        // MARK: debugging unpack feature
                        if FeatureFlags.SUPPORTS_LAYER_UNPACK {
                            Button {
                                // TODO: canvas item creation only used for debugging
                                self.debug__createUnpackedCanvasItems()
                            } label: {
                                Text("Unpack")
                            }
                        }
                    }
                
                
            case .unpacked(let unpackedPortObserver):
                ForEach(unpackedPortObserver.allPorts) { unpackedPort in
                    let canvasItemId = unpackedPort.canvasObserver?.id
                    
                    LayerInspectorPortView(layerProperty: .layerInput(unpackedPort.id),
                                           rowViewModel: unpackedPort.inspectorRowViewModel,
                                           rowObserver: unpackedPort.rowObserver,
                                           graph: graph,
                                           canvasItemId: canvasItemId) { propertyRowIsSelected in
                        NodeInputView(graph: graph,
                                      rowObserver: unpackedPort.rowObserver,
                                      rowData: unpackedPort.inspectorRowViewModel,
                                      inputLayerNodeRowData: nil, // TODO: handle properly
                                      forPropertySidebar: true,
                                      propertyIsSelected: propertyRowIsSelected,
                                      propertyIsAlreadyOnGraph: canvasItemId.isDefined,
                                      isCanvasItemSelected: false)
                    }
                }
                
            } // observerMode
        } // Group
        .onChange(of: portObserver.mode) {
            self.portObserver.wasPackModeToggled()
        }
    }
    
    // TODO: canvas item creation only used for debugging
    @MainActor func debug__createUnpackedCanvasItems() {
        // TODO: this view probably does not need the full `node` (especially in case of layer multiselect); handle the creation of unpacked canvas items should outside of the view and disallow for layer multiselect?
        fatalErrorIfDebug()
        
//                let nodeId = portObserver._packedData.rowObserver.id.nodeId
//                let parentGroupNodeId = portObserver.graphDelegate?.groupNodeFocused
//        
//                portObserver._unpackedData.allPorts.forEach { unpackedPort in
//                    var unpackSchema = unpackedPort.createSchema()
//                    unpackSchema.canvasItem = .init(position: .zero,
//                                                    zIndex: .zero,
//                                                    parentGroupNodeId: parentGroupNodeId)
//                    unpackedPort.update(from: unpackSchema,
//                                        layerInputType: unpackedPort.id,
//                                        layerNode: layerNode,
//                                        nodeId: nodeId,
//                                        nodeDelegate: node)
//                }
    }
}



struct LayerInspectorOutputPortView: View {
    let outputPortId: Int
    
    @Bindable var rowViewModel: OutputNodeRowViewModel
    @Bindable var rowObserver: OutputNodeRowObserver
    @Bindable var graph: GraphState
    
    let canvasItemId: CanvasItemId?
    
    var body: some View {
        LayerInspectorPortView(layerProperty: .layerOutput(outputPortId),
                               rowViewModel: rowViewModel,
                               rowObserver: rowObserver,
                               graph: graph,
                               canvasItemId: canvasItemId) { propertyRowIsSelected in
            NodeOutputView(graph: graph,
                           rowObserver: rowObserver,
                           rowData: rowViewModel,
                           forPropertySidebar: true,
                           propertyIsSelected: propertyRowIsSelected,
                           propertyIsAlreadyOnGraph: canvasItemId.isDefined,
                           isCanvasItemSelected: false)
        }
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
    @Bindable var rowObserver: RowObserver
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
                                    coordinate: rowObserver.id,
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
                   let canvasItemId = rowViewModel.canvasItemDelegate?.id {
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

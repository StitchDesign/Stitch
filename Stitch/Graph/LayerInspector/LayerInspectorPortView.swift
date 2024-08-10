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
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    var body: some View {
        Group {
            switch portObserver.observerMode {
            case .packed(let inputLayerNodeRowData):
                HStack {
                    Button {
                        self.portObserver.mode = .unpacked
                    } label: {
                        Text("Unpack")
                    }
                    LayerInspectorPortView(layerProperty: .layerInput(inputLayerNodeRowData.id),
                                           rowViewModel: inputLayerNodeRowData.inspectorRowViewModel,
                                           rowObserver: inputLayerNodeRowData.rowObserver,
                                           node: node,
                                           layerNode: layerNode,
                                           graph: graph) { propertyRowIsSelected, isOnGraphAlready in
                        NodeInputView(graph: graph,
                                      rowObserver: inputLayerNodeRowData.rowObserver,
                                      rowData: inputLayerNodeRowData.inspectorRowViewModel,
                                      forPropertySidebar: true,
                                      propertyIsSelected: propertyRowIsSelected,
                                      propertyIsAlreadyOnGraph: isOnGraphAlready,
                                      isCanvasItemSelected: false)
                    }
                }
                
            case .unpacked(let unpackedPortObserver):
                HStack {
                    Button {
                        self.portObserver.mode = .packed
                    } label: {
                        Text("Pack")
                    }
                    
                    ForEach(unpackedPortObserver.allPorts) { unpackedPort in
                        LayerInspectorPortView(layerProperty: .layerInput(unpackedPort.id),
                                               rowViewModel: unpackedPort.inspectorRowViewModel,
                                               rowObserver: unpackedPort.rowObserver,
                                               node: node,
                                               layerNode: layerNode,
                                               graph: graph) { propertyRowIsSelected, isOnGraphAlready in
                            NodeInputView(graph: graph,
                                          rowObserver: unpackedPort.rowObserver,
                                          rowData: unpackedPort.inspectorRowViewModel,
                                          forPropertySidebar: true,
                                          propertyIsSelected: propertyRowIsSelected,
                                          propertyIsAlreadyOnGraph: isOnGraphAlready,
                                          isCanvasItemSelected: false)
                        }
                    }
                }
            }
        }
    }
}

struct LayerInspectorOutputPortView: View {
    let outputPortId: Int
    
    @Bindable var rowViewModel: OutputNodeRowViewModel
    @Bindable var rowObserver: OutputNodeRowObserver
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    var body: some View {
        LayerInspectorPortView(layerProperty: .layerOutput(outputPortId),
                               rowViewModel: rowViewModel,
                               rowObserver: rowObserver,
                               node: node,
                               layerNode: layerNode,
                               graph: graph) { propertyRowIsSelected, isOnGraphAlready in
            NodeOutputView(graph: graph,
                           rowObserver: rowObserver,
                           rowData: rowViewModel,
                           forPropertySidebar: true,
                           propertyIsSelected: propertyRowIsSelected,
                           propertyIsAlreadyOnGraph: isOnGraphAlready,
                           isCanvasItemSelected: false)
        }
    }
}

struct LayerInspectorPortView<RowObserver, RowView>: View where RowObserver: NodeRowObserver, RowView: View {
    
    // input or output
    let layerProperty: LayerInspectorRowId
    
    @Bindable var rowViewModel: RowObserver.RowViewModelType
    @Bindable var rowObserver: RowObserver
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    // Args: 1. is row selected; 2. isOnGraph
    @ViewBuilder var rowView: (Bool, Bool) -> RowView
    
    // Is this property-row selected?
    @MainActor
    var propertyRowIsSelected: Bool {
        graph.graphUI.propertySidebar.selectedProperty == layerProperty
    }
    
    var isOnGraphAlready: Bool {
        rowViewModel.canvasItemDelegate.isDefined
    }

    @MainActor
    var listBackgroundColor: Color {
        isOnGraphAlready ? Color.black.opacity(0.3)
        : (self.propertyRowIsSelected ? STITCH_PURPLE.opacity(0.4) : .clear)
    }

    var isInputBlockedOut: Bool {
        rowViewModel.fieldValueTypes.first?.fieldObservers.allSatisfy(\.isBlockedOut) ?? false
    }

    var body: some View {
        Group {
            if isInputBlockedOut {
                Color.clear
            } else {
                rowView(propertyRowIsSelected,
                        isOnGraphAlready)
            }
        }
        .background {
            // Extending the hit area of the NodeInputOutputView view
            Color.white.opacity(0.001)
                .padding(-12)
                .padding(.trailing, -LayerInspectorView.LAYER_INSPECTOR_WIDTH)
            
            // TODO: this avoids accidentally selecting the row when using a dropdown, but then the row's overall-label and field-labels are no longer covered; so just add this .gesture to the overall-label and field-label views?
//                .gesture(
//                    TapGesture().onEnded({ _ in
//                        log("LayerInspectorPortView tapped")
//                        if isOnGraphAlready,
//                           let canvasItemId = rowViewModel.canvasItemDelegate?.id {
//                            dispatch(JumpToCanvasItem(id: canvasItemId))
//                        } else {
//                            withAnimation {
//                                graph.graphUI.layerPropertyTapped(layerProperty)
//                            }
//                        }
//                    })
//                ) // .gesture
        }
        .listRowBackground(listBackgroundColor)
        //            .listRowSpacing(12)
        .gesture(
            TapGesture().onEnded({ _ in
                // log("LayerInspectorPortView tapped")
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

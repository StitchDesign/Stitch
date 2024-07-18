//
//  LayerInspectorPortView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/24.
//

import SwiftUI
import StitchSchemaKit

struct LayerInspectorInputPortView: View {
    let layerInput: LayerInputType
    
    @Bindable var rowViewModel: InputNodeRowViewModel
    @Bindable var rowObserver: InputNodeRowObserver
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    var body: some View {
        LayerInspectorPortView(layerProperty: .layerInput(layerInput),
                               rowViewModel: rowViewModel,
                               rowObserver: rowObserver,
                               node: node,
                               layerNode: layerNode,
                               graph: graph) { propertyRowIsSelected, isOnGraphAlready in
            NodeInputView(graph: graph,
                          rowObserver: rowObserver,
                          rowData: rowViewModel,
                          forPropertySidebar: true,
                          propertyIsSelected: propertyRowIsSelected,
                          propertyIsAlreadyOnGraph: isOnGraphAlready,
                          isCanvasItemSelected: false)
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
    
    // Arguments: 1. is row selected; 2. isOnGraph
    @ViewBuilder var rowView: (Bool, Bool) -> RowView
    
    // Is this property-row selected?
    @MainActor
    var propertyRowIsSelected: Bool {
        graph.graphUI.propertySidebar.selectedProperty == layerProperty
    }
    
    var isOnGraphAlready: Bool {
        rowViewModel.canvasItemDelegate.isDefined
    }

    var body: some View {
        
        let listBackgroundColor: Color = isOnGraphAlready
            ? Color.black.opacity(0.3)
            : (self.propertyRowIsSelected
               ? STITCH_PURPLE.opacity(0.4) : .clear)
        
        // See if layer node uses this input
        rowView(propertyRowIsSelected, isOnGraphAlready)
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

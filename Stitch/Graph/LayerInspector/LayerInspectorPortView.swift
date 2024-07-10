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
    
    @Bindable var rowObserver: InputNodeRowObserver
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    var body: some View {
        LayerInspectorPortView(layerProperty: .layerInput(layerInput),
                               rowObserver: rowObserver,
                               node: node,
                               layerNode: layerNode,
                               graph: graph) { propertyRowIsSelected, isOnGraphAlready in
            NodeInputView(graph: graph,
                          node: node,
                          rowObserver: rowObserver,
                          rowData: rowObserver.rowViewModel,
                          forPropertySidebar: true,
                          propertyIsSelected: propertyRowIsSelected,
                          propertyIsAlreadyOnGraph: isOnGraphAlready,
                          isCanvasItemSelected: false)
        }
    }
}

struct LayerInspectorOutputPortView: View {
    let outputPortId: Int
    
    @Bindable var rowObserver: OutputNodeRowObserver
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    var body: some View {
        LayerInspectorPortView(layerProperty: .layerOutput(outputPortId),
                               rowObserver: rowObserver,
                               node: node,
                               layerNode: layerNode,
                               graph: graph) { propertyRowIsSelected, isOnGraphAlready in
            NodeOutputView(graph: graph,
                          node: node,
                          rowObserver: rowObserver,
                          rowData: rowObserver.rowViewModel,
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
    
    @Bindable var rowObserver: RowObserver
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    // Arguments: 1. is row selected; 2. isOnGraph
    @ViewBuilder var rowView: (Bool, Bool) -> RowView
    
    // Is this property-row selected?
    @MainActor
    var propertyRowIsSelected: Bool {
        graph.graphUI.propertySidebar
            .selectedProperties.contains(layerProperty)
    }
    
    var isOnGraphAlready: Bool {
        rowObserver.rowViewModel.canvasItemDelegate.isDefined
    }

    var body: some View {
        
        let listBackgroundColor: Color = isOnGraphAlready
            ? Color.black.opacity(0.3)
            : (self.propertyRowIsSelected
               ? STITCH_PURPLE.opacity(0.4) : .clear)
        
        // See if layer node uses this input
        rowView(propertyRowIsSelected, isOnGraphAlready)
            .listRowBackground(listBackgroundColor)
            //            .listRowSpacing(12)
//            .contentShape(Rectangle())
            .gesture(
                TapGesture().onEnded({ _ in
                    // log("LayerInspectorPortView tapped")
                    if isOnGraphAlready,
                       let canvasItemId = rowObserver.rowViewModel.canvasItemDelegate?.id {
                        dispatch(JumpToCanvasItem(id: canvasItemId))
                    } else {
                        withAnimation {
                            graph.graphUI.layerPropertyTapped(layerProperty)
                        }
                    }
                })
            )
    }
}

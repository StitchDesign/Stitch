//
//  LayerInspectorPortView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/24.
//

import SwiftUI
import StitchSchemaKit

struct LayerInspectorPortView: View {
    
    // input or output
    let layerProperty: LayerInspectorRowId
    
    @Bindable var rowObserver: NodeRowObserver
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    // Is this property-row selected?
    @MainActor
    var propertyRowIsSelected: Bool {
        graph.graphUI.propertySidebar
            .selectedProperties.contains(layerProperty)
    }
    
    var isOnGraphAlready: Bool {
        rowObserver.canvasUIData.isDefined
    }
        
    @MainActor @ViewBuilder
    var inputView: some View {
        if let portViewType = rowObserver.portViewType {
            NodeInputOutputView(graph: graph,
                                node: node,
                                rowData: rowObserver,
                                coordinateType: portViewType,
                                nodeKind: .layer(layerNode.layer),
                                isCanvasItemSelected: false, // what does this mean?
                                adjustmentBarSessionId: graph.graphUI.adjustmentBarSessionId,
                                forPropertySidebar: true,
                                propertyIsSelected: propertyRowIsSelected,
                                propertyIsAlreadyOnGraph: isOnGraphAlready)
        } else {
            EmptyView()
        }
    }
    
    @MainActor @ViewBuilder
    var outputView: some View {
        if let portViewType = rowObserver.portViewType {
            NodeInputOutputView(graph: graph,
                                node: node,
                                rowData: rowObserver,
                                coordinateType: portViewType,
                                nodeKind: .layer(layerNode.layer),
                                isCanvasItemSelected: false, // what does this mean?
                                adjustmentBarSessionId: graph.graphUI.adjustmentBarSessionId,
                                forPropertySidebar: true,
                                propertyIsSelected: propertyRowIsSelected,
                                propertyIsAlreadyOnGraph: isOnGraphAlready)
        } else {
            EmptyView()
        }
    }
    
    var body: some View {
        
        let listBackgroundColor: Color = isOnGraphAlready
            ? Color.black.opacity(0.3)
            : (self.propertyRowIsSelected
               ? STITCH_PURPLE.opacity(0.4) : .clear)
        
        // See if layer node uses this input
        Group {
            switch layerProperty {
            case .layerInput(let layerInputType):
                inputView
            case .layerOutput(let outputPortViewData):
                outputView
            }
        }
            .listRowBackground(listBackgroundColor)
            //            .listRowSpacing(12)
//            .contentShape(Rectangle())
            .gesture(
                TapGesture().onEnded({ _ in
                    // log("LayerInspectorPortView tapped")
                    if isOnGraphAlready,
                       let canvasItemId = rowObserver.canvasUIData?.id {
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

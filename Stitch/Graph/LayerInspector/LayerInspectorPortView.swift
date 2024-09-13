//
//  LayerInspectorPortView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/24.
//

import SwiftUI
import StitchSchemaKit

struct LayerInspectorInputPortView: View {
    @Bindable var layerInputObserver: LayerInputObserver
    @Bindable var graph: GraphState
    let nodeId: NodeId
    
    var body: some View {
        
        let observerMode = layerInputObserver.observerMode
        
        let layerInputType = LayerInputType(layerInput: layerInputObserver.port,
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
        
        // Does this inspector-row (the entire input) have a canvas item?
        let canvasItemId: CanvasItemId? = observerMode.isPacked ? layerInputObserver._packedData.canvasObserver?.id : nil
        
        LayerInspectorPortView(
            layerInputObserver: layerInputObserver,
            layerInspectorRowId: layerInspectorRowId,
            coordinate: coordinate,
            graph: graph,
            canvasItemId: canvasItemId) { propertyRowIsSelected in
                NodeInputView(graph: graph,
                              nodeId: nodeId,
                              nodeKind: .layer(layerInputObserver.layer),
                              hasIncomingEdge: false, // always false
                              rowObserverId: coordinate,
                              
                              // Only used for PortEntryView, which inspector- and flyout-rows do not use
                              rowObserver: nil,
                              rowViewModel: nil,
                              // Always use the packed
                              fieldValueTypes: layerInputObserver.fieldValueTypes,
                              layerInputObserver: layerInputObserver,
                              forPropertySidebar: true,
                              propertyIsSelected: propertyRowIsSelected,
                              propertyIsAlreadyOnGraph: canvasItemId.isDefined,
                              isCanvasItemSelected: false,
                              // Inspector Row always uses the overall input label, never an individual field label
                              label: layerInputObserver.overallPortLabel(usesShortLabel: true))
            }
            .onChange(of: layerInputObserver.mode) {
                self.layerInputObserver.wasPackModeToggled()
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
        
        let portId = rowViewModel.id.portId
        
        let coordinate: NodeIOCoordinate = .init(
            portType: .portIndex(portId),
            nodeId: rowViewModel.id.nodeId)

        LayerInspectorPortView(
            layerInputObserver: nil,
            layerInspectorRowId: .layerOutput(rowViewModel.id.portId),
            coordinate: coordinate,
            graph: graph, 
            canvasItemId: rowViewModel.canvasItemDelegate?.id) { propertyRowIsSelected in
                NodeOutputView(graph: graph,
                               rowObserver: rowObserver,
                               rowViewModel: rowViewModel,
                               forPropertySidebar: true,
                               propertyIsSelected: propertyRowIsSelected,
                               propertyIsAlreadyOnGraph: canvasItemId.isDefined,
                               isCanvasItemSelected: false,
                               label: rowObserver.label(true))
            }        
    }
}

// spacing between e.g. "add to graph" button (icon) and start of row capsule
let LAYER_INSPECTOR_ROW_SPACING = 8.0

// how big an icon / button is
let LAYER_INSPECTOR_ROW_ICON_LENGTH = 16.0

//struct LayerInspectorPortView<RowObserver, RowView>: View where RowObserver: NodeRowObserver, RowView: View {
struct LayerInspectorPortView<RowView>: View where RowView: View {
    
    let layerInputObserver: LayerInputObserver?
    
    // input or output
    let layerInspectorRowId: LayerInspectorRowId
    
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
            LayerInspectorRowButton(layerInputObserver: layerInputObserver,
                                    layerInspectorRowId: layerInspectorRowId,
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
                graph.graphUI.onLayerPortRowTapped(
                    layerInspectorRowId: layerInspectorRowId,
                    canvasItemId: canvasItemId)
            })
        ) // .gesture
    }
}

extension GraphUIState {
    @MainActor
    func onLayerPortRowTapped(layerInspectorRowId: LayerInspectorRowId,
                              canvasItemId: CanvasItemId?) {
        // Defined canvas item id = we're already on the canvas
        if let canvasItemId = canvasItemId {
            dispatch(JumpToCanvasItem(id: canvasItemId))
        }
        
        // Else select/de-select the property
        else {
            let alreadySelected = self.propertySidebar.selectedProperty == layerInspectorRowId
            
            withAnimation {
                if alreadySelected {
                    self.propertySidebar.selectedProperty = nil
                } else {
                    self.propertySidebar.selectedProperty = layerInspectorRowId
                }
            }
        }
    }
}


//
//  ShadowFlyoutView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/17/24.
//

import SwiftUI
import StitchSchemaKit

// Represents "packed" shadow
let SHADOW_FLYOUT_LAYER_INPUT_PROXY = LayerInputPort.shadowColor

struct ShadowFlyoutView: View {
    
    static let SHADOW_FLYOUT_WIDTH: CGFloat = 256.0
    @State var height: CGFloat? = nil // 248.87 per GeometryReader measurements?
    
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    
    var body: some View {
        
        VStack(alignment: .leading) {
            FlyoutHeader(flyoutTitle: "Shadow")
            rows
        }
        .modifier(FlyoutBackgroundColorModifier(width: Self.SHADOW_FLYOUT_WIDTH,
                                                height: self.$height))
    }
    
    @MainActor
    var rows: some View {
        VStack(alignment: .leading,
               // TODO: why must we double this *and* use padding?
               spacing: INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET * 2) {
            
            ForEach(LayerInspectorSection.shadow, id: \.self) { shadowInput in
                ShadowFlyoutRowView(node: node,
                                    shadowInput: shadowInput,
                                    layerInputObserver: layerNode[keyPath: shadowInput.layerNodeKeyPath],
                                    graph: graph,
                                    graphUI: graphUI)
            } // ForEach
        }
    }
}

// TODO: combine this view with GenericFlyoutView ? Tricky: a shadow flyout uses one LayerInspectorRowButton per input, but generic flyout uses one LayerInspectorRowButton per input-field
struct ShadowFlyoutRowView: View {
    
    let node: NodeViewModel
    let shadowInput: LayerInputPort
    let layerInputObserver: LayerInputObserver
    
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    
    @State var isHovered = false
    
    var layerInput: LayerInputPort {
        layerInputObserver.port
    }
    
    var layerInputType: LayerInputType {
        LayerInputType.init(layerInput: layerInputObserver.port,
                            portType: .packed)
    }
    
    var layerInspectorRowId: LayerInspectorRowId {
        .layerInput(layerInputType)
    }
    
    // Coordinate is used for editing, which needs to know the
    var coordinate: NodeIOCoordinate {
        .init(portType: .keyPath(layerInputType),
              nodeId: node.id)
    }
        
    var canvasItemId: CanvasItemId? {
        layerInputObserver.getCanvasItemForWholeInput()?.id
    }
    
    var propertyRowIsSelected: Bool {
        graphUI.propertySidebar.selectedProperty == layerInspectorRowId
    }
    
    var isShadowOffsetRow: Bool {
        layerInput == .shadowOffset
    }
    
    var hstackAlignment: VerticalAlignment {
        return isShadowOffsetRow ? .firstTextBaseline : .center
    }
    
    var body: some View {

        // Shadow input is *always packed*
        let layerInputData = layerInputObserver._packedData
                        
        HStack(alignment: hstackAlignment) {
            LayerInspectorRowButton(graph: graph,
                                    graphUI: graphUI,
                                    layerInputObserver: layerInputObserver,
                                    layerInspectorRowId: layerInspectorRowId,
                                    coordinate: coordinate,
                                    canvasItemId: canvasItemId,
                                    isPortSelected: propertyRowIsSelected,
                                    isHovered: isHovered)
            .offset(y: isShadowOffsetRow ? INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET : 0)
            
            NodeInputView(graph: graph,
                          graphUI: graphUI,
                          node: node,
                          hasIncomingEdge: false,
                          rowObserver: layerInputData.rowObserver,
                          rowViewModel: layerInputData.inspectorRowViewModel,
                          fieldValueTypes: layerInputData.inspectorRowViewModel.fieldValueTypes,
                          canvasItem: nil,
                          layerInputObserver: layerInputObserver,
                          forPropertySidebar: true,
                          propertyIsSelected: propertyRowIsSelected,
                          propertyIsAlreadyOnGraph: layerInputObserver.getCanvasItemForWholeInput().isDefined,
                          isCanvasItemSelected: false,
                          label: layerInputData.rowObserver
                .label(useShortLabel: true,
                       node: node,
                       graph: graph),
                          forFlyout: true)
        } // HStack
        
        .padding([.top, .bottom], INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET * 2)
        
        .onChange(of: layerInputObserver.mode) {
            // Unpacked modes not supported here
            assertInDebug(layerInputObserver.mode == .packed)
        }
        .contentShape(Rectangle())
        .onHover(perform: { hovering in
            self.isHovered = hovering
        })
        .onTapGesture {
            graphUI.onLayerPortRowTapped(
                layerInspectorRowId: layerInspectorRowId,
                canvasItemId: canvasItemId,
                graph: graph)
        }
    }
    
}

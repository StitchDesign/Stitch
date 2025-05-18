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
    @Bindable var document: StitchDocumentViewModel
    
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
                                    document: document)
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
    @Bindable var document: StitchDocumentViewModel
    
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
    
    var isShadowOffsetRow: Bool {
        layerInput == .shadowOffset
    }
    
    var hstackAlignment: VerticalAlignment {
        return isShadowOffsetRow ? .firstTextBaseline : .center
    }
    
    var isSelectedInspectorRow: Bool {
        graph.propertySidebar.selectedProperty == .layerInput(
            LayerInputType(layerInput: layerInputObserver.port,
                           // Shadow is always packed
                           portType: .packed))
    }
    
    var body: some View {
        HStack(alignment: hstackAlignment) {
            LayerInspectorRowButton(graph: graph,
                                    layerInputObserver: layerInputObserver,
                                    layerInspectorRowId: layerInspectorRowId,
                                    coordinate: coordinate,
                                    packedInputCanvasItemId: canvasItemId,
                                    isHovered: isHovered,
                                    // a flyout's use of a theme is determined only by whether it is the selected row (on iPad)
                                    usesThemeColor: isSelectedInspectorRow)
            
            .offset(y: isShadowOffsetRow ? INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET : 0)
            
            InspectorLayerInputView(document: document,
                                    graph: graph,
                                    node: node,
                                    layerInputObserver: layerInputObserver,
                                    forFlyout: true,
                                    isSelectedInspectorRow: isSelectedInspectorRow)
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
            document.onLayerPortRowTapped(
                layerInspectorRowId: layerInspectorRowId,
                canvasItemId: canvasItemId,
                graph: graph)
        }
    }
    
}

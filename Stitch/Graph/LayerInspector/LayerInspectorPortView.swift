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
    @Bindable var graphUI: StitchDocumentViewModel
    let node: NodeViewModel
    
    var fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>] {
        layerInputObserver.fieldValueTypes
    }
    
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
            nodeId: node.id)
        
        // Does this inspector-row (the entire input) have a canvas item?
        let canvasItemId: CanvasItemId? = observerMode.isPacked ? layerInputObserver._packedData.canvasObserver?.id : nil
        
        LayerInspectorPortView(
            layerInputObserver: layerInputObserver,
            layerInspectorRowId: layerInspectorRowId,
            coordinate: coordinate,
            graph: graph,
            graphUI: graphUI,
            canvasItemId: canvasItemId) { propertyRowIsSelected in
                NodeInputView(graph: graph,
                              graphUI: graphUI,
                              node: node,
                              hasIncomingEdge: false, // always false
                              
                              // we can use packed data since this is purely visual
                              rowObserver: layerInputObserver._packedData.rowObserver,
                              rowViewModel: layerInputObserver._packedData.inspectorRowViewModel,
                              // Always use the packed
                              fieldValueTypes: self.fieldValueTypes,
                              canvasItem: nil,
                              layerInputObserver: layerInputObserver,
                              forPropertySidebar: true,
                              propertyIsSelected: propertyRowIsSelected,
                              propertyIsAlreadyOnGraph: canvasItemId.isDefined,
                              isCanvasItemSelected: false,
                              // Inspector Row always uses the overall input label, never an individual field label
                              label: layerInputObserver
                    .overallPortLabel(usesShortLabel: true,
                                      currentTraversalLevel: graphUI.groupNodeFocused?.groupNodeId,
                                      node: node,
                                      graph: graph)
                )
            }
        
        // NOTE: this fires unexpectedly, so we rely on canvas item deletion and `layer input field added to canvas` to handle changes in pack vs unpacked mode.
//            .onChange(of: layerInputObserver.mode) { oldValue, newValue in
//                self.layerInputObserver.wasPackModeToggled()
//            }
    }
}

struct LayerInspectorOutputPortView: View {
    let outputPortId: Int
    
    @Bindable var node: NodeViewModel
    @Bindable var rowViewModel: OutputNodeRowViewModel
    @Bindable var rowObserver: OutputNodeRowObserver
    @Bindable var graph: GraphState
    @Bindable var graphUI: StitchDocumentViewModel
    
    let canvasItemId: CanvasItemId?
    
    var body: some View {
        
        let portId = rowViewModel.id.portId
        
        let coordinate: NodeIOCoordinate = .init(
            portType: .portIndex(portId),
            nodeId: rowViewModel.id.nodeId)

        // Does this inspector-row (entire output) have a canvas item?
        // Note: CANNOT rely on delegate since weak var references do not trigger view updates
//        let canvasItemId: CanvasItemId? = rowViewModel.canvasItemDelegate?.id
        let canvasItemId: CanvasItemId? = graph.getCanvasItem(outputId: coordinate)?.id
        
        LayerInspectorPortView(
            layerInputObserver: nil,
            layerInspectorRowId: .layerOutput(rowViewModel.id.portId),
            coordinate: coordinate,
            graph: graph,
            graphUI: graphUI,
            canvasItemId: canvasItemId) { propertyRowIsSelected in
                NodeOutputView(graph: graph,
                               graphUI: graphUI,
                               node: node,
                               rowObserver: rowObserver,
                               rowViewModel: rowViewModel,
                               canvasItem: nil,
                               forPropertySidebar: true,
                               propertyIsSelected: propertyRowIsSelected,
                               propertyIsAlreadyOnGraph: canvasItemId.isDefined,
                               isCanvasItemSelected: false,
                               label: rowObserver
                    .label(useShortLabel: true,
                           node: node,
                           currentTraversalLevel: graphUI.groupNodeFocused?.groupNodeId,
                           graph: graph)
                )
            }
    }
}

// spacing between e.g. "add to graph" button (icon) and start of row capsule
let LAYER_INSPECTOR_ROW_SPACING = 8.0

// how big an icon / button is
let LAYER_INSPECTOR_ROW_ICON_LENGTH = 16.0

//struct LayerInspectorPortView<RowObserver, RowView>: View where RowObserver: NodeRowObserver, RowView: View {
struct LayerInspectorPortView<RowView>: View where RowView: View {
    
    // This ought to be non-optional?
    let layerInputObserver: LayerInputObserver?
    
    // input or output
    let layerInspectorRowId: LayerInspectorRowId
    
    let coordinate: NodeIOCoordinate
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    
    // non-nil = this row is present on canvas
    // NOTE: apparently, the destruction of a weak var reference does NOT trigger a SwiftUI view update; so, avoid using delegates in the UI body.
    let canvasItemId: CanvasItemId?
    
    // Arguments: 1. is row selected
    @ViewBuilder var rowView: (Bool) -> RowView
    
    @State private var isHovered: Bool = false
    
    // Is this property-row selected?
    @MainActor
    var propertyRowIsSelected: Bool {
        graph.propertySidebar.selectedProperty == layerInspectorRowId
    }
    
    var isOnGraphAlready: Bool {
        canvasItemId.isDefined
    }
    
    var isPaddingPortValueTypeRow: Bool {
        layerInputObserver?.port == .layerMargin || layerInputObserver?.port == .layerPadding
    }
    
    var isShadowProxyRow: Bool {
        layerInputObserver?.port == SHADOW_FLYOUT_LAYER_INPUT_PROXY
    }
    
    var hstackAlignment: VerticalAlignment {
        return isPaddingPortValueTypeRow ? .firstTextBaseline : .center
    }
    
    var body: some View {
        HStack(alignment: hstackAlignment) {
            
            LayerInspectorRowButton(graph: graph,
                                    graphUI: graphUI,
                                    layerInputObserver: layerInputObserver,
                                    layerInspectorRowId: layerInspectorRowId,
                                    coordinate: coordinate,
                                    canvasItemId: canvasItemId,
                                    isPortSelected: propertyRowIsSelected,
                                    isHovered: isHovered)
            // TODO: `.firstTextBaseline` doesn't align symbols and text in quite the way we want;
            // Really, we want the center of the symbol and the center of the input's label text to align
            // Alternatively, we want the height of the row-buton to be the same as the height of the input-row's label, e.g. specify a height in `LabelDisplayView`
            .offset(y: isPaddingPortValueTypeRow ? INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET : 0)
            
            // Do not show this button if this is the row for the shadow proxy
            .opacity(isShadowProxyRow ? 0 : 1)
                        
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
        .modifier(LayerInspectorPortViewTapModifier(graph: graph,
                                                    graphUI: graphUI,
                                                    isAutoLayoutRow: layerInputObserver?.port == .orientation,
                                                    layerInspectorRowId: layerInspectorRowId,
                                                    canvasItemId: canvasItemId))
    }
}

// HACK: Catalyst's Segmented Picker is unresponsive when we attach a tap gesture, even a `.simultaneousGesture(TapGesture)`
struct LayerInspectorPortViewTapModifier: ViewModifier {
    
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    let isAutoLayoutRow: Bool
    let layerInspectorRowId: LayerInspectorRowId
    let canvasItemId: CanvasItemId?
        
    var isCatalyst: Bool {
#if targetEnvironment(macCatalyst)
        return true
#else
        return false
#endif
    }
    
    func body(content: Content) -> some View {
        // HACK: If this is the LayerGroup's autolayout row (on Catalyst) and the row is not already on the canvas,
        // then do not add a 'jump to canvas item' handler that interferes with Segmented Picker.
        if isAutoLayoutRow, isCatalyst, canvasItemId == nil {
            content
        } else {
            content.gesture(TapGesture().onEnded({ _ in
                log("LayerInspectorPortView tapped")
                graphUI.onLayerPortRowTapped(
                    layerInspectorRowId: layerInspectorRowId,
                    canvasItemId: canvasItemId,
                    graph: graph)
            }))
        }
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func onLayerPortRowTapped(layerInspectorRowId: LayerInspectorRowId,
                              canvasItemId: CanvasItemId?,
                              graph: GraphState) {
        // Defined canvas item id = we're already on the canvas
        if let canvasItemId = canvasItemId {
            graph.jumpToCanvasItem(id: canvasItemId,
                                   document: self)
        }
        
        // Else select/de-select the property
        else {

            // On Catalyst, use hover-only, never row-selection.
            #if !targetEnvironment(macCatalyst)
            let alreadySelected = graph.propertySidebar.selectedProperty == layerInspectorRowId
            
            withAnimation {
                if alreadySelected {
                    graph.propertySidebar.selectedProperty = nil
                } else {
                    graph.propertySidebar.selectedProperty = layerInspectorRowId
                }
            }
            #endif
        }
    }
}


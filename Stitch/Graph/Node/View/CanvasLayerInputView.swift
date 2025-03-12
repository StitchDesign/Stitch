//
//  CanvasLayerInputView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/10/25.
//

import SwiftUI

// see `LayerNodeInputView`
struct CanvasLayerInputView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvasNode: CanvasItemViewModel
    let layerInputObserver: LayerInputObserver
    let inputRowObserver: InputNodeRowObserver
    let inputRowViewModel: InputNodeRowViewModel
    let isNodeSelected: Bool
                
    @ViewBuilder @MainActor
    func valueEntryView(portViewModel: InputFieldViewModel,
                        isMultiField: Bool) -> InputValueEntry {
        InputValueEntry(graph: graph,
                        graphUI: document,
                        viewModel: portViewModel,
                        node: node,
                        rowViewModel: inputRowViewModel,
                        canvasItem: canvasNode,
                        rowObserver: inputRowObserver,
                        isCanvasItemSelected: isNodeSelected,
                        hasIncomingEdge: inputRowObserver.upstreamOutputCoordinate.isDefined,
                        isForLayerInspector: false,
                        isPackedLayerInputAlreadyOnCanvas: true, // Always true for canvas layer input
                        isFieldInMultifieldInput: isMultiField,
                        isForFlyout: false,
                        isSelectedInspectorRow: false, // Always false for canvas layer input
                        useIndividualFieldLabel: true)
    }
    
    var body: some View {
        HStack {
            LabelDisplayView(label: layerInputObserver.overallPortLabel(usesShortLabel: false,
                                                                        node: node,
                                                                        graph: graph),
                             isLeftAligned: false,
                             fontColor: STITCH_FONT_GRAY_COLOR,
                             isSelectedInspectorRow: false)
            
            // Unpacked 3D Transform fields on the canvas are a special case;
            // e.g. they need "Position X" not just "X"
            if layerInputObserver.port == .transform3D,
               layerInputObserver.mode == .unpacked,
               let rowLabel = inputRowObserver.id.keyPath?.getUnpackedPortType?.fieldGroupLabelForUnpacked3DTransformInput {
                
                LabelDisplayView(label: rowLabel,
                                 isLeftAligned: false,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 isSelectedInspectorRow: false)
            }
            
            LayerInputFieldsView(fieldValueTypes: inputRowViewModel.fieldValueTypes,
                                 layerInputObserver: layerInputObserver,
                                 forFlyout: false,
                                 valueEntryView: valueEntryView)
        }
        .modifier(CanvasPortHeightModifier())
    }
}

struct CanvasPortHeightModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .height(NODE_ROW_HEIGHT + 8)
    }
}

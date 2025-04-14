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
            
            LayerInputFieldsView(layerInputFieldType: .canvas(canvasNode),
                                 document: document,
                                 graph: graph,
                                 node: node,
                                 rowObserver: inputRowObserver,
                                 rowViewModel: inputRowViewModel,
                                 fieldValueTypes: inputRowViewModel.cachedFieldValueGroups,
                                 layerInputObserver: layerInputObserver,
                                 isNodeSelected: isNodeSelected)
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

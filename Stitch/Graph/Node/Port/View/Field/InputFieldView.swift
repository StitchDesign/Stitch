//
//  ValueEntry.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import StitchSchemaKit

// For an individual field
// fka `InputValueEntry`
struct InputFieldView: View {
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    
    @Bindable var inputField: InputFieldViewModel
    let node: NodeViewModel
    
    let rowId: NodeRowViewModelId
    let layerInputPort: LayerInputPort?
    
    let canvasItemId: CanvasItemId?
    
    let rowObserver: InputNodeRowObserver
    let isCanvasItemSelected: Bool
    let hasIncomingEdge: Bool
    
    // TODO: package these up into `InspectorData` ?
    let isForLayerInspector: Bool
    let isPackedLayerInputAlreadyOnCanvas: Bool
    let isFieldInMultifieldInput: Bool
    let isForFlyout: Bool
    let isSelectedInspectorRow: Bool
    
    let useIndividualFieldLabel: Bool
    
    // Used by button view to determine if some button has been pressed.
    // Saving this state outside the button context allows us to control renders.
    @State private var isButtonPressed = false
    
    var individualFieldLabelDisplay: LabelDisplayView {
        LabelDisplayView(label: inputField.fieldLabel,
                         isLeftAligned: true,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         isSelectedInspectorRow: isSelectedInspectorRow)
    }
    
    @MainActor
    var valueDisplay: some View {
        InputFieldValueView(graph: graph,
                            document: document,
                            inputField: inputField,
                            propertySidebar: graph.propertySidebar,
                            node: node,
                            rowId: rowId,
                            layerInputPort: layerInputPort,
                            canvasItemId: canvasItemId,
                            rowObserver: rowObserver,
                            isForLayerInspector: isForLayerInspector,
                            isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                            isFieldInMultifieldInput: isFieldInMultifieldInput,
                            isForFlyout: isForFlyout,
                            isSelectedInspectorRow: isSelectedInspectorRow,
                            hasIncomingEdge: hasIncomingEdge, // Only for pulse button and color orb; always false for inspector rows
                            isForLayerGroup: node.kind.getLayer == .group,
                            isButtonPressed: $isButtonPressed)
        .font(STITCH_FONT)
        // Monospacing prevents jittery node widths if values change on graphstep
        .monospacedDigit()
        .lineLimit(1)
    }
    
    var showIndividualFieldLabel: Bool {
        // Show individual field labels
        isForFlyout || (self.isFieldInMultifieldInput && self.useIndividualFieldLabel)
    }
    
    var body: some View {
        HStack(spacing: NODE_COMMON_SPACING) {
            
            if showIndividualFieldLabel {
                individualFieldLabelDisplay
            }
            
            if isForFlyout,
               isFieldInMultifieldInput {
                Spacer()
            }
            
            valueDisplay
        }
        .foregroundColor(VALUE_FIELD_BODY_COLOR)
        .height(NODE_ROW_HEIGHT + 6)
        .allowsHitTesting(!(isForLayerInspector && isPackedLayerInputAlreadyOnCanvas))
    }
    
}

extension UnpackedPortType {
    // see the `.transform3D` case in `getFieldValueTypes`:
    // ASSUMES THIS IS A PORT TYPE FOR
    var fieldGroupLabelForUnpacked3DTransformInput: String {
        switch self {
        case .port0, .port1, .port2:
            return "Position"
        case .port3, .port4, .port5:
            return "Scale"
        case .port6, .port7, .port8:
            return "Rotation"
        }
    }
}


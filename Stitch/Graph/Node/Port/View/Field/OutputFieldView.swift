//
//  OutputFieldView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/25.
//

import SwiftUI


// fka `OutputValueEntry`
struct OutputFieldView: View {

    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var outputField: OutputFieldViewModel

    let rowViewModel: OutputNodeRowViewModel
    let rowObserver: OutputNodeRowObserver
    let node: NodeViewModel
        
    let isForLayerInspector: Bool
    
    let isFieldInMultifieldInput: Bool
    
    let isSelectedInspectorRow: Bool

    // Used by button view to determine if some button has been pressed.
    // Saving this state outside the button context allows us to control renders.
    @State private var isButtonPressed = false
    
    var labelDisplay: some View {
        LabelDisplayView(label: self.outputField.fieldLabel,
                         isLeftAligned: false,
                         fontColor: STITCH_FONT_GRAY_COLOR,
                         usesThemeColor: isSelectedInspectorRow)
    }
    
    var valueDisplay: some View {
        OutputFieldValueView(graph: graph,
                             document: document,
                             outputField: outputField,
                             rowViewModel: rowViewModel,
                             rowObserver: rowObserver,
                             node: node,
                             isForLayerInspector: isForLayerInspector,
                             isFieldInMultifieldInput: isFieldInMultifieldInput,
                             isSelectedInspectorRow: isSelectedInspectorRow,
                             isButtonPressed: $isButtonPressed)
        .font(STITCH_FONT)
        // Monospacing prevents jittery node widths if values change on graphstep
        .monospacedDigit()
        .lineLimit(1)
    }

    var body: some View {
        HStack(spacing: NODE_COMMON_SPACING) {
            labelDisplay
            valueDisplay
        }
        .foregroundColor(VALUE_FIELD_BODY_COLOR)
        .height(NODE_ROW_HEIGHT + 6)
    }

}

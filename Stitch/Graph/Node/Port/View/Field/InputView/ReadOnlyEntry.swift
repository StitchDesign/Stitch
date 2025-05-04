//
//  ReadOnlyEntry.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

// TODO: OutputView's fields should support clicking and highlighting? Can be done via a TextField that receives a .constant(stringValue) binding.

// TODO: remove this in favor of StitchTextView, or is it worthwhile to have a separate view for later potential changes to 'read only' value displays?
struct ReadOnlyValueEntry: View {
    
    @Environment(\.appTheme) var theme
    
    let value: String

    // left alignment for all inputs and multifield outputs
    // right alignment for single-field outputs
    let alignment: Alignment // = .trailing
    var fontColor: Color = STITCH_FONT_GRAY_COLOR
    let isSelectedInspectorRow: Bool
    
    let isForLayerInspector: Bool
    let isFieldInMultifieldInput: Bool
    
    @MainActor
    var fieldWidth: CGFloat {
         if isFieldInMultifieldInput && isForLayerInspector {
            return INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH
        } else {
            return NODE_INPUT_OR_OUTPUT_WIDTH
        }
    }
    
    var body: some View {
        StitchTextView(string: value,
                       fontColor: fontColor)
            // Monospacing prevents jittery node widths if values change on graphstep
            .monospacedDigit()
            .frame(width: fieldWidth,
                   alignment: alignment)
            .padding([.leading, .top, .bottom], 2) // padding to mat
                
        // TODO: `NODE_INPUT_OR_OUTPUT_WIDTH * 1.5` is long enough for CoreML's "No Results" but too long for most other cases; but e.g. the DeviceInfo node's outputs properly need more space
        //            .frame(minWidth: NODE_INPUT_OR_OUTPUT_WIDTH * 1.5,
        //                   maxWidth: NODE_INPUT_OR_OUTPUT_WIDTH * 2,
        //                   alignment: alignment)
        //            .border(.blue)
    }
}

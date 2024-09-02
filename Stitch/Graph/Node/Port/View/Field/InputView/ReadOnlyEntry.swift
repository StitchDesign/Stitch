//
//  ReadOnlyEntry.swift
//  prototype
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

    var body: some View {
        StitchTextView(string: value,
                       fontColor: isSelectedInspectorRow ? theme.fontColor : fontColor)
            // Monospacing prevents jittery node widths if values change on graphstep
            .monospacedDigit()
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   alignment: alignment)
    }
}

// struct ReadOnlyEntry_Previews: PreviewProvider {
//    static var previews: some View {
//        ReadOnlyEntry()
//    }
// }

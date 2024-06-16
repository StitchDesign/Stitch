//
//  LabelDisplayView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import SwiftUI
import StitchSchemaKit

struct LabelDisplayView: View {

    let label: String
    let isLeftAligned: Bool
    var fontColor: Color = STITCH_FONT_WHITE_COLOR

    var body: some View {

        // Empty view for empty string important to remove extra padding
        if label.isEmpty {
            EmptyView()
        } else {
            StitchTextView(string: label,
                           fontColor: fontColor)
                .frame(alignment: isLeftAligned ? .leading : .trailing)
                .fixedSize() // Do not let parent shrink this child view
        }
    }
}

struct LabelDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        LabelDisplayView(label: "X", isLeftAligned: true)
    }
}

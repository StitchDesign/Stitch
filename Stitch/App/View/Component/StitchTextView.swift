//
//  StitchTextView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

// Wrapper over SwiftUI Text,
// to use our app-wide fonts and font-color
struct StitchTextView: View {
    let string: String
    var font: Font = STITCH_FONT
    var fontColor: Color = STITCH_TITLE_FONT_COLOR
//    var fontColor: Color
    var lineLimit: Int?
    var truncationMode: Text.TruncationMode?

    var body: some View {
        Text(string)
            .font(font)
            .foregroundColor(fontColor)
            .lineLimit(lineLimit)
            .truncationMode(truncationMode ?? .tail)
    }
}

struct TruncatedTextView: View {
    let string: String
    let color: Color

    // MARK: the string building below has bad perf
    init(_ string: String, 
         truncateAt: Int,
         color: Color) {
        if string.count > truncateAt {
            let endIndex = string.index(string.startIndex, offsetBy: truncateAt)
            self.string = String(string[..<endIndex]) + "…"
        } else {
            self.string = string
        }
        self.color = color
    }

    var body: some View {
        Text(string)
            .font(STITCH_FONT)
//            .foregroundColor(STITCH_TITLE_FONT_COLOR)
            .foregroundColor(color)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

var CAPTION_VIEW_COLOR: Color = Color(.captionView)

struct StitchCaptionView: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(.custom("SFProText-Regular", size: 13))
            .foregroundColor(CAPTION_VIEW_COLOR)
    }
}

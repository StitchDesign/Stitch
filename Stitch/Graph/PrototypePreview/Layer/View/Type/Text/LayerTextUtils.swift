//
//  LayerTextUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension LayerTextDecoration: PortValueEnum {
    static let defaultLayerTextDecoration = Self.none
    static let defaultLayerTextDecorationPortValue = PortValue.textDecoration(Self.defaultLayerTextDecoration)

    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.textDecoration
    }

    var isUnderline: Bool {
        self == .underline
    }

    var isStrikethrough: Bool {
        self == .strikethrough
    }

    var display: String {
        switch self {
        case .none:
            return "None"
        case .underline:
            return "Underline"
        case .strikethrough:
            return "Strikethrough"
        }
    }
}

// Alignment options for our Text Layers in preview window
extension LayerTextAlignment: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.textAlignment
    }

    // Note: SwiftUI TextField does not support .justify
    var asMultilineAlignment: TextAlignment? {
        switch self {
        case .center:
            return .center
        case .left:
            return .leading
        case .right:
            return .trailing
        case .justify:
            return nil
        }
    }

    var display: String {
        switch self {
        case .left:
            return "Left"
        case .center:
            return "Center"
        case .right:
            return "Right"
        case .justify:
            return "Justify"
        }
    }

}

extension LayerTextVerticalAlignment: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.textVerticalAlignment
    }

    var asVerticalAlignmentForTextField: Alignment {
        switch self {
        case .top:
            return .top
        case .center:
            return .center
        case .bottom:
            return .bottom
        }
    }

    var display: String {
        switch self {
        case .top:
            return "Top"
        case .center:
            return "Center"
        case .bottom:
            return "Bottom"
        }
    }
}

// Turns a textAlignment and a verticalAlignment
// into a SwiftUI .frame(alignment:) value.
func getSwiftUIAlignment(_ textAlignment: LayerTextAlignment,
                         _ verticalAlignment: LayerTextVerticalAlignment) -> Alignment? {

    // justified text requires UITextView,
    // which does not use SwiftUI alignments.
    if textAlignment == .justify {
        return nil
    }

    switch (textAlignment, verticalAlignment) {
    case (.left, .top):
        return .topLeading
    case (.left, .center):
        return .leading
    case (.left, .bottom):
        return .bottomLeading
    case (.right, .top):
        return .topTrailing
    case (.right, .center):
        return .trailing
    case (.right, .bottom):
        return .bottomTrailing
    // .center, .justify have same left/right placement
    case (_, .top):
        return .top
    case (_, .center):
        return .center
    case (_, .bottom):
        return .bottom
    }
}

let DEFAULT_LAYER_TEXT_FONT_SIZE: CGFloat = 36

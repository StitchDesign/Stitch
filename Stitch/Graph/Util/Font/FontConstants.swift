//
//  FontConstants.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import UIKit

let STITCH_FONT: Font = stitchFont(14.53)
let STITCH_UIFONT: UIFont = .systemFont(
    ofSize: 14,
    weight: .medium).rounded()

let STITCH_ROUNDED_FONT: Font = .init(STITCH_ROUNDED_UIFONT)
let STITCH_ROUNDED_UIFONT: UIFont = UIFont.init(name: "SFCompactRounded-Medium", size: 14.53)!

let STITCH_FONT_WHITE_COLOR: Color = Color(.stitchWhite)

let STITCH_FONT_GRAY_COLOR: Color = Color(.stitchGray)

let STITCH_TITLE_FONT_COLOR: Color = Color(.nodeTitleFont)

// black in Light mode; white in Dark mode
let STITCH_EDIT_BUTTON_COLOR: Color = Color(.editButton)

let VALUE_FIELD_BODY_COLOR: Color = Color(.valueFieldBody)

let INSERT_NODE_MENU_SEARCH_TEXT: Color = Color(.insertNodeMenuTitle)

// white in light mode, gray in dark mode
let LAYER_INSPECTOR_ROW_CAPSULE_COLOR: Color = Color(.layerInspectorRowCapsule)
let WHITE_IN_LIGHT_MODE_GRAY_IN_DARK_MODE = LAYER_INSPECTOR_ROW_CAPSULE_COLOR

let SIDE_BAR_OPTIONS_TITLE_FONT_COLOR: Color = Color(.sideBarOptionsTitleFont)

let CATALYST_TOP_BAR_ICON_SIZE = CGSize(width: 17, height: 17)
let CATALYST_PROJECT_ICON_SIZE = CGSize(width: 32, height: 32)
let CATALYST_PROJECT_OVERFLOW_ICON_SIZE = CGSize(width: 20, height: 20)

let STITCH_NODE_TAG_FONT: Font = .system(
    size: 12,
    weight: .regular,
    design: Font.Design.rounded)

let WINDOW_NAVBAR_FONT: Font = .system(
    size: 16,
    weight: .medium)

let WINDOW_NAVBAR_UIFONT: UIFont = .systemFont(
    ofSize: 16,
    weight: .medium)

let BREADCRUMB_FONT: Font = .system(
    size: 20,
    weight: .medium)

let BREADCRUMB_UIFONT: UIFont = .systemFont(
    ofSize: 20,
    weight: .medium)

let HEADER_LEVEL_1_FONT = UIFont(name: "SFProText-Medium", size: 24)
let HEADER_LEVEL_2_FONT = UIFont(name: "SFProText-Regular", size: 14)

func stitchFont(_ size: CGFloat) -> Font {
    Font.system(size: size, weight: .medium, design: .rounded)
}

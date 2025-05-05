//
//  CommonEditingViewHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/25.
//

import Foundation
import SwiftUI

extension Color {
    // Not completely white in light mode, not completely dark in dark mode
    static let SIDEBAR_AND_INSPECTOR_BACKGROUND_COLOR = Color(.sheetBackground)
    
    static let BLACK_IN_LIGHT_MODE_WHITE_IN_DARK_MODE: Color = Color(.lightModeBlackDarkModeWhite)
    
    static let WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE: Color = Self.SIDEBAR_AND_INSPECTOR_BACKGROUND_COLOR //Color(.lightModeWhiteDarkModeBlack)
    
    static let INSPECTOR_FIELD_BACKGROUND_COLOR = Color(.inspectorFieldBackground)
    
#if DEV_DEBUG
    static let COMMON_EDITING_VIEW_READ_ONLY_BACKGROUND_COLOR: Color = .blue.opacity(0.5)
    static let COMMON_EDITING_VIEW_EDITABLE_FIELD_BACKGROUND_COLOR: Color = .green.opacity(0.5)
#else
    static let COMMON_EDITING_VIEW_READ_ONLY_BACKGROUND_COLOR: Color = INPUT_FIELD_BACKGROUND
    static let COMMON_EDITING_VIEW_EDITABLE_FIELD_BACKGROUND_COLOR: Color = INPUT_FIELD_BACKGROUND
#endif
}

extension CGFloat {
    static let COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH = 12.0
    static let COMMON_EDITING_DROPDOWN_CHEVRON_HEIGHT = COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH - 4.0
}

// node field input/output width, per Figma Spec
let NODE_INPUT_OR_OUTPUT_WIDTH: CGFloat = 56

// Need additional space since LayerDimension has the dropdown chevron + can display a percent
let LAYER_DIMENSION_FIELD_WIDTH: CGFloat = 68

// the soulver node needs more width
let SOULVER_NODE_INPUT_OR_OUTPUT_WIDTH: CGFloat = 90

let TEXT_FONT_DROPDOWN_WIDTH: CGFloat = 200
let SPACING_FIELD_WIDTH: CGFloat = 68
let PADDING_FIELD_WDITH: CGFloat = 36

// TODO: alternatively, allow these fields to size themselves?
let INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH: CGFloat = 44
//let INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH: CGFloat = NODE_INPUT_OR_OUTPUT_WIDTH

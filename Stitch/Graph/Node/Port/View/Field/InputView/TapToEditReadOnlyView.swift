//
//  CommonEditingViewReadOnly.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/30/24.
//

import SwiftUI
import StitchSchemaKit

extension StitchTheme {
    var fontColor: Color {
        self.themeData.edgeColor
    }
}

// The "read-only" view for "TapToEditView"
struct TapToEditReadOnlyView: View {
        
    @Environment(\.appTheme) var theme
    
    let inputString: String
    
    let fieldWidth: CGFloat
    let isFocused: Bool
    let isHovering: Bool
    let isForLayerInspector: Bool
    
    let hasPicker: Bool
    
    // Only relevant for inspector or flyout, never a canvas  field
    let fieldHasHeterogenousValues: Bool
    
    let usesThemeColor: Bool
        
    let onTap: () -> Void
    
    var displayString: String {
        self.fieldHasHeterogenousValues ? .HETEROGENOUS_VALUES : self.inputString
    }
        
    var body: some View {
        // If can tap to edit, and this is a number field,
        // then bring up the number-adjustment-bar first;
        // for multifields now, the editType value is gonna be a parentValue of eg size or position
        StitchTextView(string: displayString,
                       font: STITCH_FONT,
                       fontColor: usesThemeColor ? theme.fontColor : STITCH_FONT_GRAY_COLOR)

        .modifier(InputFieldFrameAndPadding(
            width: fieldWidth,
            hasPicker: hasPicker))
        
        .modifier(InputFieldBackgroundColorView(
            isHovering: isHovering,
            isFocused: isFocused,
            isForLayerInspector: isForLayerInspector,
            usesThemeColor: usesThemeColor))
                
        // Manually focus this field when user taps.
        // Better as global redux-state than local view-state: only one field in entire app can be focused at a time.
        .onTapGesture {
            self.onTap()
        }
    }
}

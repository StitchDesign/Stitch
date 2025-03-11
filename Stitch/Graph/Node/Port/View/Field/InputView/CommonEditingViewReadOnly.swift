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

struct CommonEditingViewReadOnly: View {
        
    @Environment(\.appTheme) var theme
    
    @Bindable var inputField: InputFieldViewModel
    let inputString: String
    let forPropertySidebar: Bool
    let isHovering: Bool
    let choices: [String]?
    let fieldWidth: CGFloat
    let fieldHasHeterogenousValues: Bool
    let isSelectedInspectorRow: Bool
    
    let isFieldInMultfieldInspectorInput: Bool
    
    let onTap: () -> Void
    
    var displayString: String {
        self.fieldHasHeterogenousValues ? .HETEROGENOUS_VALUES : self.inputString
    }
    
    var hasPicker: Bool {
        choices.isDefined && !isFieldInMultfieldInspectorInput
    }
    
    var body: some View {
        // If can tap to edit, and this is a number field,
        // then bring up the number-adjustment-bar first;
        // for multifields now, the editType value is gonna be a parentValue of eg size or position
        StitchTextView(string: displayString,
                       font: STITCH_FONT,
                       fontColor: isSelectedInspectorRow ? theme.fontColor : STITCH_FONT_GRAY_COLOR)
        .modifier(InputViewBackground(
            show: self.isHovering || self.forPropertySidebar,
            hasDropdown: self.hasPicker,
            forPropertySidebar: forPropertySidebar,
            isSelectedInspectorRow: isSelectedInspectorRow,
            width: fieldWidth))
        
        // Manually focus this field when user taps.
        // Better as global redux-state than local view-state: only one field in entire app can be focused at a time.
        .onTapGesture {
            self.onTap()
        }
    }
}

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
    
    // let forPropertySidebar: Bool

    //    let isCanvasField: Bool
    
    let fieldWidth: CGFloat
    let isFocused: Bool
    let isHovering: Bool
    let isForLayerInspector: Bool
    
    let choices: [String]?
    
//    let hasPicker: Bool // choices.isDefined && !isFieldInMultfieldInspectorInput
    
    let fieldHasHeterogenousValues: Bool
    let isSelectedInspectorRow: Bool
    
//    let isFieldInMultfieldInspectorInput: Bool
    
    let onTap: () -> Void
    
    var displayString: String {
        self.fieldHasHeterogenousValues ? .HETEROGENOUS_VALUES : self.inputString
    }
    
//    var hasPicker: Bool {
//        choices.isDefined && !isFieldInMultfieldInspectorInput
//    }
    
    var body: some View {
        // If can tap to edit, and this is a number field,
        // then bring up the number-adjustment-bar first;
        // for multifields now, the editType value is gonna be a parentValue of eg size or position
        StitchTextView(string: displayString,
                       font: STITCH_FONT,
                       fontColor: isSelectedInspectorRow ? theme.fontColor : STITCH_FONT_GRAY_COLOR)
//        .modifier(InputFieldBackground(
//            show: self.isHovering || self.forPropertySidebar,
//            hasDropdown: self.hasPicker,
//            forPropertySidebar: forPropertySidebar,
//            isSelectedInspectorRow: isSelectedInspectorRow,
//            isCanvasField: self.isCanvasField,
//            width: fieldWidth,
//            isHovering: isHovering,
//            onTap: self.onTap))
        
        .modifier(InputFieldFrameAndPadding(
            width: fieldWidth,
            hasDropdown: choices.isDefined))
        
        .modifier(InputFieldBackgroundColorView(
            isHovering: isHovering,
            isFocused: isFocused,
            isForLayerInspector: isForLayerInspector,
            isSelectedInspectorRow: isSelectedInspectorRow))
        
        // TODO: needs a slightly wider background?
        
        // Manually focus this field when user taps.
        // Better as global redux-state than local view-state: only one field in entire app can be focused at a time.
        .onTapGesture {
            self.onTap()
        }
    }
}

//
//  StitchSheetInput.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/13/22.
//

import SwiftUI
import StitchSchemaKit

let STITCH_SHEET_INPUT_BACKGROUND_COLOR = Color(.sheetBackground)

/// View modifier which applies styling for inputs in sheets.
struct StitchSheetInput: ViewModifier {
    func body(content: Content) -> some View {
        return content
            .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
            .height(40)
            .background(STITCH_SHEET_INPUT_BACKGROUND_COLOR)
            .border(Color(uiColor: .systemGray3))
            .cornerRadius(12)
    }
}

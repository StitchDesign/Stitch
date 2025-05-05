//
//  TapToEditTextPickerView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/25.
//

import SwiftUI


// MARK: PICKER

extension TapToEditTextView {
            
    func textFieldViewWithPicker(_ choices: [String]) -> some View {
        HStack(spacing: 0) {
            
            textFieldView
            
            /*
             Important: must .overlay `picker` on a view that does not change when field is focused/defocused.
             
             `HStack { textFieldView, picker }` introduces alignment issues from picker's SwiftUI Menu/Picker
             
             `textFieldView.overlay { picker }` causes picker to flash when the underlying text-field / read-only-text view is changed via if/else.
             */
            Rectangle().fill(.clear).frame(width: 1, height: 1)
                .overlay {
                    pickerView(choices)
                        .offset(x: -.COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH/2)
                        .offset(x: -2) // "padding"
                }
        }
    }
    
    // Only used in a handful of cases, e.g. LayerDimension (`fill`, `auto`), Spacing (`equal`) etc.
    @MainActor
    func pickerView(_ choices: [String]) -> some View {
        Menu {
            Picker("", selection: $pickerChoice) {
                ForEach(self.choices ?? [], id: \.self) {
                    Text($0)
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .resizable()
                .frame(width: .COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH,
                       height: .COMMON_EDITING_DROPDOWN_CHEVRON_HEIGHT)
                .padding(8) // increase hit area
        }
        
        // TODO: why must we hide the native menuIndicator?
        .menuIndicator(.hidden) // hides caret indicator
        
#if targetEnvironment(macCatalyst)
        .menuStyle(.button)
        .buttonStyle(.plain) // fixes Catalyst accent-color issue
        .foregroundColor(STITCH_FONT_GRAY_COLOR)
        .pickerStyle(.inline) // avoids unnecessary middle label
#endif

        // TODO: this fires as soon as the READ-ONLY view is rendered, which we don't want.
        // When dropdown item selected, update text-field's string
        .onChange(of: self.pickerChoice, initial: false) { oldValue, newValue in
            if let _ = self.choices?.first(where: { $0 == newValue }) {
                // log("on change of choice: valid new choice")
                self.currentEdit = newValue
                self.inputEditedCallback(newEdit: newValue,
                                         isCommitting: true)
            }
        }
        
        // When text-field's string edited to be an exact match for a dropdown item, update the dropdown's selection.
        .onChange(of: self.currentEdit) { oldValue, newValue in
            if let x = self.choices?.first(where: { $0.lowercased() == self.currentEdit.lowercased() }) {
                // log("found choice \(x)")
                self.pickerChoice = x
            }
            
            // If we edited the input to something other than an available choice, reset the picker's current selection (e.g. "fill") to empty,
            // so that selecting a picker option again will the `.onChange(of: self.pickerChoice)` that updates the field's underlying value etc.
            else {
                self.pickerChoice = ""
            }
        }
    } // var layerDimensionPicker
}

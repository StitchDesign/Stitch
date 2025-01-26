//
//  NodeTextEditingField.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/25/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct CustomTextFieldModifier: ViewModifier {
    let alignment: TextAlignment

    func body(content: Content) -> some View {
        content
            .multilineTextAlignment(alignment)
    }
}

/// Abstracts common logic away from `TextField`'s for the purpose of tracking which input
/// in the app is focused.
// TODO: remove this? No longer needed?
struct StitchTextEditingField: View {
    @FocusState private var isFocused: Bool
    @State var currentEdit: String = ""
    let fieldType: FocusedUserEditField
    var canvasDimensionInput: String?
    let shouldFocus: Bool
    var isForNodeTitle = false
    var font: Font = STITCH_FONT
    var fontColor: Color = STITCH_TITLE_FONT_COLOR
    let fieldEditCallback: @MainActor (String, Bool) -> ()
    
    var body: some View {
        StitchTextEditingBindingField(currentEdit: $currentEdit,
                                      fieldType: fieldType,
                                      canvasDimensionInput: canvasDimensionInput,
                                      isForNodeTitle: isForNodeTitle,
                                      font: font,
                                      fontColor: fontColor,
                                      fieldEditCallback: fieldEditCallback)
            .onChange(of: self.shouldFocus, initial: true) { oldValue, newValue in
                self.isFocused = newValue
            }
    }
}

/// Abstracts common logic away from `TextField`'s for the purpose of tracking which input
/// in the app is focused.
// TODO: ?: break up into smaller, composable components and create separate input-edit vs node title-edit views
struct StitchTextEditingBindingField: View {
    @Environment(StitchStore.self) private var store

    // Save initial value to see if we need persistence
    @State private var initialValue: String = ""
    @State private var hasSubmitted = false
    
    @FocusState private var isFocused: Bool
    
    // Passed in from parent view; can be edited by `CommonEditingView`
    @Binding var currentEdit: String
        
    let fieldType: FocusedUserEditField

    // When StitchTextEditingField is used in ProjectSettingsView's canvas dimension input,
    // the 'swap dimensions' button is a case where a redux update overrides user's current input,
    // which can never happen in our node input use case.
    var canvasDimensionInput: String?

    var isForNodeTitle = false

    var font: Font = STITCH_FONT
    var fontColor: Color = STITCH_TITLE_FONT_COLOR

    let fieldEditCallback: (String, Bool) -> ()
    
    var isBase64 = false

    var isEmptyTitleEdit: Bool {
        isForNodeTitle && self.currentEdit.isEmpty
    }

    @MainActor
    func textFieldEditAction(isCommitting: Bool = false) {
        
        // MARK: important to keep isFocused check here else edges may be lost from InputEdit action getting called
        if isFocused {
            self.fieldEditCallback(self.currentEdit, isCommitting)
        }
    }

    func titleFieldValidator() {
        if isEmptyTitleEdit {
            self.currentEdit = Self.longEmptyString
        }
    }

    @MainActor
    func submitChanges() {
        textFieldEditAction(isCommitting: true)
        titleFieldValidator()
        self.hasSubmitted = true
    }

    // For easier clickability of node titles when user has edited the string to otherwise be empty
    static let longEmptyString = "                 "

    var body: some View {
        TextField(isBase64 ? "base64" : "", text: $currentEdit)
            .font(font)
            .foregroundColor(fontColor)
            .truncationMode(.tail)
            .lineLimit(1)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .modifier(CustomTextFieldModifier(alignment: .leading))
            .focused($isFocused)
            .onSubmit {
                submitChanges()
            }
            // When we tap on a node title that has a long empty string (for easier clickability),
            // we turn that long empty string into the regular empty string,
            // so as not to have extra spaces in the user's edit.
            .onTapGesture {
                if isForNodeTitle,
                   self.currentEdit == Self.longEmptyString {
                    self.currentEdit = ""
                }
            }
            .onAppear {
                // log("StitchTextEditingBindingField: onAppear")
                self.initialValue = isBase64 ? "" : self.currentEdit
                self.isFocused = true
                
                // Note: when tabbing or shift-tabbing, our focus-related data can be correct yet (intermittently) the TextField defocuses.
                // So we do an additional focus when field first appears.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    // log("StitchTextEditingBindingField: onAppear: callback")
                    self.isFocused = true
                }
            }
            .onDisappear {
                    
                // Best placed here because .onDisappear fires exactly 1x whether we submit or click-away
                if let document = store.currentDocument,
                   let coordinate: FieldCoordinate = fieldType.getTextInputEdit,
                   let nodeViewModel = document.graph.getNode(coordinate.rowId.nodeId),
                   let input = nodeViewModel.getInputRowObserver(for: coordinate.rowId.portType) {
                    
                   let parentPortValue = input.activeValue
                       
                   let newValue = parentPortValue.parseInputEdit(
                    fieldValue: .string(.init(self.currentEdit)),
                    fieldIndex: coordinate.fieldIndex)
                                        
                    document.maybeCreateLLMStepSetInput(
                        node: nodeViewModel,
                        input: input.id,
                        value: newValue)
                } // if let document = ...
                
                // log("StitchTextEditingBindingField: onDisappear")
                self.isFocused = false // added
                dispatch(TextFieldDisappeared(focusedField: fieldType))
                if self.initialValue != self.currentEdit && !hasSubmitted {
                    // log("StitchTextEditingBindingField: encode project.")
                    self.store.encodeCurrentProject()
                }
            }
            .onChange(of: self.isFocused, { oldValue, newValue in
                 // log("StitchTextEditingBindingField: .onChange(of: self.isFocused): oldValue: \(oldValue)")
                 // log("StitchTextEditingBindingField: .onChange(of: self.isFocused): newValue: \(newValue)")
                // Logic for when we lose focus
                if !newValue {
                    titleFieldValidator()
                }
                
                if newValue {
                    dispatch(ReduxFieldFocused(focusedField: fieldType))
                } else {
                    dispatch(ReduxFieldDefocused(focusedField: fieldType))
                }
            })
            .onChange(of: currentEdit) { _, _ in
                self.textFieldEditAction()
            }
            .onChange(of: canvasDimensionInput) { _, newValue in
                if let newLabel = newValue {
                    self.currentEdit = newLabel
                }
            }
        // When an input's field is focused, we treat an up- or down-arrow as a user "increment" or "decrement" input
            .onChange(of: self.store.currentDocument?.graphUI.reduxFocusedFieldChangedByArrowKey) { _, _ in
                if let numberEdit = self.store.currentDocument?.graph.handleArrowKeyInput(self.currentEdit) {
                    self.currentEdit = numberEdit
                }
            }
    }
}

extension GraphState {
    
    @MainActor
    func handleArrowKeyInput(_ currentEdit: String) -> String? {
        
        guard self.graphUI.reduxFocusedField?.getTextInputEdit.isDefined ?? false, // only for an input's fields, not node title etc.
              let arrowKey = self.graphUI.reduxFocusedFieldChangedByArrowKey else {
            
            log("handleArrowKeyInput: no text field focused or no relevant arrow key")
            self.graphUI.reduxFocusedFieldChangedByArrowKey = nil
            
            return nil
        }
        
        // Always wipe
        self.graphUI.reduxFocusedFieldChangedByArrowKey = nil
                
        // If we had a regular, non-percentage number:
        if let n: Double = toNumber(currentEdit) {
            switch arrowKey {
            case .upArrow:
                return (n + 1).formattedForFieldDisplay()
            case .downArrow:
                return (n - 1).formattedForFieldDisplay()
            }
        } else if let n = toNumberFromPercentage(currentEdit) {
            switch arrowKey {
            case .upArrow:
                return (n + 1).asPercentage
            case .downArrow:
                return (n - 1).asPercentage
            }
        } else {
            log("handleArrowKeyInput: did not have a number or percent")
            return nil
        }
    }
}

struct TextFieldDisappeared: StitchDocumentEvent {
    let focusedField: FocusedUserEditField
    
    func handle(state: StitchDocumentViewModel) {
        if state.graphUI.reduxFocusedField == focusedField {
            state.graphUI.reduxFocusedField = nil
        }
        
        /*
         On iPad, de-rendering a TextField messes up the responder-chain, such that we do not receive a "presses ended" event.
         So, we manually remove the TAB and SHIFT modifiers when the TextField disappears.
         TAB and SHIFT are the only key presses that could trigger the disappearance of the TextField.
         */
        #if !targetEnvironment(macCatalyst)
        state.keypressState.modifiers.remove(.tab)
        state.keypressState.modifiers.remove(.shift)
        #endif
    }
}

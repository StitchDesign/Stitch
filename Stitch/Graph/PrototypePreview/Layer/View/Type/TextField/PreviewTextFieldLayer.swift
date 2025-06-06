//
//  PreviewTextFieldLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/4/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PreviewTextFieldLayer: View {
    @FocusedValue(\.focusedField) private var focusedField
    @FocusState private var isFocused: Bool
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    
    let placeholder: String
    let color: Color
    let position: CGPoint
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
    let fontSize: LayerDimension
    let textAlignment: LayerTextAlignment
    let verticalAlignment: LayerTextVerticalAlignment
    let textDecoration: LayerTextDecoration
    let textFont: StitchFont
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    let pivot: Anchoring
    
    let shadowColor: Color
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: StitchPosition
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool
    
    var id: PreviewCoordinate {
        interactiveLayer.id
    }
    
    var usedFocusedField: FocusedUserEditField {
        .prototypeTextField(id)
    }
    
    // We cannot use TextField while creating a project thumbnail
    @ViewBuilder @MainActor
    var previewTextField: some View {
        // SwiftUI TextField cannot be rendered
        if document.isGeneratingProjectThumbnail {
            LayerTextView(value: viewModel.textFieldInput,
                          color: color,
                          alignment: getSwiftUIAlignment(textAlignment,
                                                         verticalAlignment),
                          fontSize: fontSize,
                          textDecoration: textDecoration,
                          textFont: textFont)
            .opacity(opacity)
            .padding()
        } else {
            textFieldWithOnChangeLogic
        }
    }
    
    var isSpellCheckEnabled: Bool {
        if let enabled = viewModel.isSpellCheckEnabled.getBool {
            return enabled
        }
        return false
    }
    
    var keyboardType: KeyboardType {
        if let keyboardType = viewModel.keyboardType.getKeyboardType {
            return keyboardType
        }
        return KeyboardType.defaultKeyboard
    }
    
    var isSecureEntry: Bool {
        if let isSecureEntry = viewModel.isSecureEntry.getBool {
            return isSecureEntry
        }
        return false
    }
    
    var regularVsSecureEntryField: some View {
        Group {
            if self.isSecureEntry {
                SecureField("",
                            text: $viewModel.textFieldInput,
                            // Use a color that shows up against the common scenario of a white prototype window background
                            prompt: Text(placeholder).foregroundColor(Color(.lightGray))
                )
                .textContentType(.password)
            } else {
                TextField("",
                          text: $viewModel.textFieldInput,
                          // Use a color that shows up against the common scenario of a white prototype window background
                          prompt: Text(placeholder).foregroundColor(Color(.lightGray))
                )
            }
        }
    }
    
    
    @MainActor
    var textFieldWithOnChangeLogic: some View {

        regularVsSecureEntryField
        
        // TODO: no longer needed anymore? replaced by redux-focused-field ?
             .focusedValue(\.focusedField, .prototypeTextField(self.id))

        // MARK: important: whether text field is focused or not; updated by redux-state changes *but also can trigger updates to redux-state*
             .focused($isFocused)
        
        // QWERTY vs number pad etc.
            .keyboardType(self.keyboardType.asUIKeyboardType)
        
        // Only auto-correct if spellcheck is enabled
            .autocorrectionDisabled(!self.isSpellCheckEnabled)
            
        // TODO: allow user to specify auto-capitalization logic?
            .autocapitalization(.none)
            
            .multilineTextAlignment(textAlignment.asMultilineAlignment ?? .leading)
        
            .font(.system(size: fontSize.getNumber ?? .DEFAULT_FONT_SIZE,
                          weight: textFont.fontWeight.asFontWeight,
                          design: textFont.fontChoice.asFontDesign))
            .underline(textDecoration.isUnderline, pattern: .solid)
            .strikethrough(textDecoration.isStrikethrough, pattern: .solid)
            .foregroundColor(color)
        
        
        // User submits --> we de-focus
            .onSubmit {
                dispatch(ReduxFieldDefocused(focusedField: usedFocusedField))
            }
        
        // User tapped on field -> we toggle focus
            .onTapGesture {
                if self.isFocused {
                    dispatch(ReduxFieldDefocused(focusedField: usedFocusedField))
                } else {
                    dispatch(ReduxFieldFocused(focusedField: usedFocusedField))
                }
            }
        
            .opacity(opacity)
            .padding()
        
        // VERY IMPORTANT to fix iPad-specific fullscreen-preview issue
            .background(Color.HITBOX_COLOR)
        
        // MARK: onChange methods
        
        // User typed in the text-field -> we send updates to layer node's output
            .onChange(of: self.viewModel.textFieldInput) { oldValue, newValue in
                // log("TextField: onChange: self.edit: oldValue: \(oldValue)")
                // log("TextField: onChange: self.edit: newValue: \(newValue)")
                // TODO: slight delay not necessary?
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                    dispatch(TextFieldInputEdited(id: id, newEdit: newValue))
                }
            }
          
        
        // Redux-focused-field changed -> we update text field's focus
            .onChange(of: document.reduxFocusedField, initial: true) { oldValue, newValue in
                 // log("TextField: onChange: document.reduxFocusedField: oldValue: \(oldValue)")
                 // log("TextField: onChange: document.reduxFocusedField: newValue: \(newValue)")
                
                switch newValue {
                case .prototypeTextField(let focusedId):
                    let _focused = focusedId == self.id
                    // log("TextField: onChange: document.reduxFocusedField: might focus: _focused: \(_focused)")
                    self.isFocused = _focused
                default:
                    // log("TextField: onChange: document.reduxFocusedField: will defocus")
                    self.isFocused = false
                }
            }
        
        // SwiftUI TextField's focus changed (e.g. because user tapped) --> we update redux
        // Note: handles an interesting where  tapping on a text field in the prototype window *also* triggers a "prototype window focused" event, which was overriding the redux tracking of this text-field's focused-state
            .onChange(of: self.isFocused, initial: true) { oldValue, newValue in
                // log("TextField: onChange: self.isFocused: oldValue: \(oldValue)")
                // log("TextField: onChange: self.isFocused: newValue: \(newValue)")
                if newValue {
                    dispatch(ReduxFieldFocused(focusedField: usedFocusedField))
                } else {
                    dispatch(ReduxFieldDefocused(focusedField: usedFocusedField))
                }
            }
        
            .id(self.localId)
            .onChange(of: self.keyboardType, initial: true) {
                self.localId = .init()
            }
            .onChange(of: self.isSpellCheckEnabled, initial: true) {
                self.localId = .init()
            }
    }
    
    // Note: must force re-render for keyboard-type (and auto-correct?) change(s) to take effect
    @State var localId = UUID()
    
    var body: some View {
        previewTextField.modifier(PreviewCommonModifier(
            document: document,
            graph: graph,
            layerViewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: interactiveLayer,
            position: position,
            rotationX: rotationX,
            rotationY: rotationY,
            rotationZ: rotationZ,
            size: size,
            scale: scale,
            anchoring: anchoring,
            blurRadius: blurRadius,
            blendMode: blendMode,
            brightness: brightness,
            colorInvert: colorInvert,
            contrast: contrast,
            hueRotation: hueRotation,
            saturation: saturation,
            pivot: pivot,
            shadowColor: shadowColor,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowOffset: shadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid,
            frameAlignment: verticalAlignment.asVerticalAlignmentForTextField))
    }
}

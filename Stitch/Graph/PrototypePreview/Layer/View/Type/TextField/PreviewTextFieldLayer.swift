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

    let focusedTextFieldLayer: PreviewCoordinate?

    // Don't need to explicitly handle
    @FocusState private var isFocused: Bool
    
    var id: PreviewCoordinate {
        interactiveLayer.id
    }
    
    var usedFocusedField: FocusedUserEditField {
        .textFieldLayer(id)
    }
    
    @ViewBuilder @MainActor
    var previewTextField: some View {
        // SwiftUI TextField cannot be rendered
        if graph.isGeneratingProjectThumbnail {
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
            textFieldView
        }
    }
    
    @MainActor
    var textFieldView: some View {
        
        TextField(placeholder,
                  text: $viewModel.textFieldInput)
            .autocorrectionDisabled()
            .autocapitalization(.none)
            .multilineTextAlignment(textAlignment.asMultilineAlignment ?? .leading)
            .focused($isFocused)
            .font(.system(size: fontSize.getNumber ?? .DEFAULT_FONT_SIZE,
                          weight: textFont.fontWeight.asFontWeight,
                          design: textFont.fontChoice.asFontDesign))
            .underline(textDecoration.isUnderline, pattern: .solid)
            .strikethrough(textDecoration.isStrikethrough, pattern: .solid)
            .foregroundColor(color)
            .onSubmit {
                dispatch(ReduxFieldDefocused(focusedField: usedFocusedField))
            }

            .onTapGesture {
                if self.isFocused {
                    dispatch(ReduxFieldDefocused(focusedField: usedFocusedField))
                } else {
                    dispatch(ReduxFieldFocused(focusedField: usedFocusedField))
                }
            }
            .onChange(of: self.viewModel.textFieldInput) { _, newValue in
                // log("TextField: onChange: self.edit: oldValue: \(oldValue)")
                // log("TextField: onChange: self.edit: newValue: \(newValue)")
                // TODO: slight delay not necessary?
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                    dispatch(TextFieldInputEdited(id: id, newEdit: newValue))
                }
            }
            .opacity(opacity)
            .padding()
            .onChange(of: self.focusedTextFieldLayer, initial: true) { _, _ in
                // log("TextField: onChange: self.focusedTextFieldLayer: oldValue: \(oldValue)")
                // log("TextField: onChange: self.focusedTextFieldLayer: newValue: \(newValue)")
                if let focusedId = focusedTextFieldLayer,
                   focusedId == id {
                    // log("TextField: onChange: self.focusedTextFieldLayer: will focus")
                    self.isFocused = true
                } else {
                    // log("TextField: onChange: self.focusedTextFieldLayer: will defocus")
                    self.isFocused = false
                }
            }
        
        // VERY IMPORTANT to fix iPad-specific fullscreen-preview issue
            .background(Color.HITBOX_COLOR)
    }
    
    var body: some View {

        previewTextField.modifier(PreviewCommonModifier(
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
            frameAlignment: verticalAlignment.asVerticalAlignmentForTextField))
    }
}

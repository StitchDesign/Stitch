//
//  TextFieldLayerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/3/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let DEFAULT_TEXT_PLACEHOLDER_VALUE = String("PlaceHolder")

extension LayerSize {
    static let DEFAULT_TEXT_FIELD_SIZE: Self = .init(width: 300, height: 100)
}

struct TextFieldLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.textField
        
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(layerInputs: Self.inputDefinitions,
              outputs: [.init(label: "Field",
                              type: .string)],
              layer: Self.layer)
    }
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .color,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .pivot,
        .masks,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing)
        .union(.pinning)
        .union(.layerPaddingAndMargin)
        .union(.offsetInGroup)
        .union(.typographyWithoutText)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        PreviewTextFieldLayer(
            document: document,
            graph: graph,
            viewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            placeholder: viewModel.placeholderText.display,
            color: viewModel.color.getColor ?? falseColor,
            position: viewModel.position.getPosition ?? .zero,
            rotationX: viewModel.rotationX.asCGFloat,
            rotationY: viewModel.rotationY.asCGFloat,
            rotationZ: viewModel.rotationZ.asCGFloat,
            size: viewModel.size.getSize ?? .zero,
            opacity: viewModel.opacity.getNumber ?? .zero,
            scale: viewModel.scale.getNumber ?? .zero,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            fontSize: viewModel.fontSize.getLayerDimension ?? .DEFAULT_FONT_SIZE,
            textAlignment: viewModel.textAlignment.getLayerTextAlignment ?? DEFAULT_TEXT_ALIGNMENT,
            verticalAlignment: viewModel.verticalAlignment.getLayerTextVerticalAlignment ?? DEFAULT_TEXT_VERTICAL_ALIGNMENT,
            textDecoration: viewModel.textDecoration.getTextDecoration ?? .defaultLayerTextDecoration,
            textFont: viewModel.textFont.getTextFont ?? .defaultStitchFont,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            pivot: viewModel.pivot.getAnchoring ?? .defaultPivot,
            shadowColor: viewModel.shadowColor.getColor ?? .defaultShadowColor,
            shadowOpacity: viewModel.shadowOpacity.getNumber ?? .defaultShadowOpacity,
            shadowRadius: viewModel.shadowRadius.getNumber ?? .defaultShadowOpacity,
            shadowOffset: viewModel.shadowOffset.getPosition ?? .defaultShadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid,
            focusedTextFieldLayer: document.graphUI.reduxFocusedField?.getTextFieldLayerInputEdit)
    }
}

// puts string edit from text-field layer view model into the text-field layer node's output (by index)
@MainActor
func textFieldLayerEval(node: NodeViewModel) -> EvalResult {

    guard let layerNodeViewModel = node.layerNode,
          layerNodeViewModel.layer == .textField else {
        fatalErrorIfDebug()
        return .init(outputsValues: [])
    }
    
    let textFieldLayerViewModels = layerNodeViewModel.previewLayerViewModels

    let evalOp: OpWithIndex<PortValue> = { _, loopIndex in

        // Note: on the initial evaluation of this layer node, we will not have yet have any `textFieldLayerViewModels`. That's fine; the node eval works fine afterward.
        let textFieldValueAtIndex = textFieldLayerViewModels[safe: loopIndex]?.textFieldInput ?? ""

        // log("textFieldLayerEval: values: \(values)")
        // log("textFieldLayerEval: loopIndex: \(loopIndex)")
        // log("textFieldLayerEval: textFieldValueAtIndex: \(textFieldValueAtIndex)")

        return PortValue.string(.init(textFieldValueAtIndex))
    }

    let newOutput = loopedEval(node: node, evalOp: evalOp)
    // log("textFieldLayerEval: newOutput: \(newOutput)")

    return .init(outputsValues: [newOutput])
}


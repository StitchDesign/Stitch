//
//  ButtonLayerNode.swift
//  Stitch
//
//  Created by Alex on 1/3/25.
//

import StitchSchemaKit
import SwiftUI

struct ButtonLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.button

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(layerInputs: self.inputDefinitions,
              outputs: [
                .init(label: "Tapped",
                      type: .pulse)
              ],
              layer: Self.layer)
    }
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .text,
        .backgroundColor,
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
        .cornerRadius,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.typographyWithoutTextFieldInputs)
        .union(.pinning)
        .union(.layerPaddingAndMargin)
        .union(.offsetInGroup)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        PreviewButtonLayer(
            document: document,
            graph: graph,
            viewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            id: viewModel.previewCoordinate,
            text: viewModel.text.display,
            backgroundColor: viewModel.backgroundColor.getColor ?? .clear,
            textColor: viewModel.color.getColor ?? .primary,
            position: viewModel.position.getPosition ?? .zero,
            rotationX: viewModel.rotationX.getNumber ?? .zero,
            rotationY: viewModel.rotationY.getNumber ?? .zero,
            rotationZ: viewModel.rotationZ.getNumber ?? .zero,
            size: viewModel.size.getSize ?? DEFAULT_BUTTON_SIZE,
            opacity: viewModel.opacity.getNumber ?? 1.0,
            scale: viewModel.scale.getNumber ?? 1.0,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            cornerRadius: viewModel.cornerRadius.getNumber ?? 8.0,
            fontSize: viewModel.fontSize.getLayerDimension ?? .DEFAULT_FONT_SIZE,
            textAlignment: viewModel.textAlignment.getLayerTextAlignment ?? DEFAULT_TEXT_ALIGNMENT,
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
            shadowRadius: viewModel.shadowRadius.getNumber ?? .defaultShadowRadius,
            shadowOffset: viewModel.shadowOffset.getPosition ?? .defaultShadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid)
    }
}

struct ButtonLayerTapped: GraphEvent {
    let id: PreviewCoordinate
    
    func handle(state: GraphState) {
        state.scheduleForNextGraphStep(id.layerNodeId.id)
    }
}

struct PreviewButtonLayer: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let id: PreviewCoordinate
    let text: String
    let backgroundColor: Color
    let textColor: Color
    let position: CGPoint
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
    let cornerRadius: Double
    let fontSize: LayerDimension
    let textAlignment: LayerTextAlignment
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

    var body: some View {
        Button(action: {
            dispatch(ButtonLayerTapped(id: id))
        }) {
            Text(text)
                .font(textFont.font(fontSize.asCGFloat))
                .foregroundColor(textColor)
                .multilineTextAlignment(textAlignment.textAlignment)
                .frame(
                    width: size.width.asCGFloat(parentSize.width),
                    height: size.height.asCGFloat(parentSize.height)
                )
                .background(backgroundColor)
                .cornerRadius(cornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
        .modifier(PreviewCommonModifier(
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
            parentIsScrollableGrid: parentIsScrollableGrid
        ))
    }
}

let BUTTON_NODE_MINIMUM_DRAG_DISTANCE = 5.0

let DEFAULT_BUTTON_SIZE = CGSize(width: 100, height: 44).toLayerSize

let DEFAULT_BUTTON_TEXT = "Button"

@MainActor
func buttonLayerEval(node: NodeViewModel,
                     graphStep: GraphStepState) -> EvalResult {

    guard let layerNodeViewModel = node.layerNode else {
        fatalErrorIfDebug()
        return .init(outputsValues: [[.pulse(.zero)]])
    }

    let buttonLayerViewModels = layerNodeViewModel.previewLayerViewModels

    let evalOp: OpWithIndex<PortValue> = { values, loopIndex in
        
        guard let layerViewModel = buttonLayerViewModels[safe: loopIndex] else {
            return .pulse(.zero)
        }

        let interactiveLayer = layerViewModel.interactiveLayer
        let wasTapped = interactiveLayer.singleTapped
        let currentGraphTime = graphStep.graphTime
        
        let pulseValue: TimeInterval = wasTapped ? currentGraphTime : .zero
        
        // Reset the tapped state after processing
        if wasTapped {
            interactiveLayer.singleTapped = false
        }
        
        return .pulse(pulseValue)
    }

    let newOutput = loopedEval(node: node, evalOp: evalOp)

    return .init(outputsValues: [newOutput])
}
//
//  ProgressIndicatorLayerNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 3/26/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

struct ProgressIndicatorLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.progressIndicator
    
    static let inputDefinitions: LayerInputTypeSet = .init([
        .isAnimating,
        .progressIndicatorStyle,
        .progress,
        .position,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning)
    
    static func content(graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, isGeneratedAtTopLevel: Bool,
                        parentDisablesPosition: Bool) -> some View {
        PreviewProgressIndicatorLayer(
            graph: graph,
            layerViewModel: viewModel,
            isGeneratedAtTopLevel: isGeneratedAtTopLevel,
            interactiveLayer: viewModel.interactiveLayer,
            animating: Binding<Bool>(
                get: { viewModel.isAnimating.getBool ?? true },
                set: { viewModel.isAnimating = .bool($0) }
            ),
            style: viewModel.progressIndicatorStyle.getProgressIndicatorStyle ?? .circular,
            progress: viewModel.progress.getNumber ?? 0.5,
            position: viewModel.position.getPosition ?? .zero,
            size: DEFAULT_CIRCULAR_PROGRESS_INDICATOR_SIZE,
            opacity: viewModel.opacity.getNumber ?? .zero,
            scale: viewModel.scale.getNumber ?? .zero,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            pivot: viewModel.pivot.getAnchoring ?? .defaultPivot,
            shadowColor: .defaultShadowColor,
            shadowOpacity: .defaultShadowOpacity,
            shadowRadius: .defaultShadowRadius,
            shadowOffset: .defaultShadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition)
    }
}

struct PreviewProgressIndicatorLayer: View {
    @Bindable var graph: GraphState
    let layerViewModel: LayerViewModel
    let isGeneratedAtTopLevel: Bool
    let interactiveLayer: InteractiveLayer
    @Binding var animating: Bool
    var style: ProgressIndicatorStyle
    var progress: Double
    let position: CGSize
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
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
    
    var body: some View {
        Group {
            if animating {
                if style == .circular {
                    ProgressView().progressViewStyle(CircularProgressViewStyle())
                } else if style == .linear {
                    let clampedProgress = min(max(progress, 0), 1)
                    ProgressView(value: clampedProgress).progressViewStyle(LinearProgressViewStyle())
                        .tint(.blue)
                }
            }
        }
        .opacity(opacity)
        .modifier(PreviewCommonModifier(
            graph: graph,
            layerViewModel: layerViewModel,
            isGeneratedAtTopLevel: isGeneratedAtTopLevel,
            interactiveLayer: interactiveLayer,
            position: position,
            rotationX: 0,
            rotationY: 0,
            rotationZ: 0,
//            size: size.asCGSize(parentSize),
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
            parentDisablesPosition: parentDisablesPosition
        ))
    }
}

let DEFAULT_CIRCULAR_PROGRESS_INDICATOR_SIZE = CGSizeMake(40, 40).toLayerSize
let DEFAULT_LINEAR_PROGRESS_INDICATOR_SIZE = CGSizeMake(140, 40).toLayerSize
let DEFAULT_PROGRESS_VALUE = Double(0.5)

func progressIndicatorStyleCoercer(_ values: PortValues) -> PortValues {
    values
        .map { $0.coerceToProgressIndicatorStyle() }
        .map(PortValue.progressIndicatorStyle)
}

extension PortValue {
    // Takes any PortValue, and returns a StitchMapType
    func coerceToProgressIndicatorStyle() -> ProgressIndicatorStyle {
        switch self {
        case .progressIndicatorStyle(let x):
            return x
        case .number(let x):
            return ProgressIndicatorStyle.fromNumber(x).getProgressIndicatorStyle ?? .circular
        default:
            return .circular
        }
    }
}

extension ProgressIndicatorStyle: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<ProgressIndicatorStyle> {
        PortValue.progressIndicatorStyle
    }
}

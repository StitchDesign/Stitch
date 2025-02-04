//
//  SFSymbolLayerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/23/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let DEFAULT_SF_SYMBOL = String("pencil.and.scribble")

struct SFSymbolLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.sfSymbol
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .sfSymbol,
        .color,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        // .fitStyle, // FitStyle is not relevant, since SFSymbol's do not have inherent aspect ratio?
        .scale,
        .anchoring,
        .zIndex,
        .cornerRadius, // not used?
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
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        
        let stroke = viewModel.getLayerStrokeData()
        
        return PreviewSFSymbolLayer(
            document: document,
            graph: graph,
            layerViewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            sfSymbol: viewModel.sfSymbol.getString?.string ?? "",
            color: viewModel.color.getColor ?? falseColor,
            position: viewModel.position.getPosition ?? .zero,
            rotationX: viewModel.rotationX.getNumber ?? .zero,
            rotationY: viewModel.rotationY.getNumber ?? .zero,
            rotationZ: viewModel.rotationZ.getNumber ?? .zero,
            size: viewModel.size.getSize ?? .zero,
            opacity: viewModel.opacity.getNumber ?? defaultOpacityNumber,
            scale: viewModel.scale.getNumber ?? defaultScaleNumber,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            stroke: stroke,
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
            parentIsScrollableGrid: parentIsScrollableGrid)
    }
}


struct PreviewSFSymbolLayer: View {
    let document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let layerViewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let sfSymbol: String
    let color: Color
    let position: StitchPosition
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
    let stroke: LayerStrokeData
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

        Image(systemName: sfSymbol)
            .resizable()
            .foregroundColor(color)
            .opacity(opacity)
            .modifier(PreviewCommonModifier(
                document: document,
                graph: graph,
                layerViewModel: layerViewModel,
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
                parentIsScrollableGrid: parentIsScrollableGrid))
    }
}

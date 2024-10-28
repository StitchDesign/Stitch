//
//  GroupLayerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/4/21.
//

import Combine
import Foundation
import StitchSchemaKit
import SwiftUI
import Tagged

// Used for VStack vs HStack on layer groups
extension StitchOrientation: PortValueEnum {
    static let defaultOrientation = Self.none

    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.orientation
    }

    var display: String {
        switch self {
        case .none:
            return "None"
        case .horizontal:
            return "Horizontal"
        case .vertical:
            return "Vertical"
        case .grid:
            return "Grid"
        }
    }

    var isOrientated: Bool {
        switch self {
        case .horizontal, .vertical, .grid:
            return true
        case .none:
            return false
        }
    }
}

// Defaults to iPhone 11 preview window size
let DEFAULT_GROUP_SIZE = CGSize(width: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.width,
                                height: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.height).toLayerSize

let DEFAULT_GROUP_POSITION = CGSize.zero

let DEFAULT_GROUP_CLIP_SETTING: Bool = true

let DEFAULT_GROUP_PADDING: CGFloat = 0

let DEFAULT_GROUP_BACKGROUND_COLOR: Color = .clear

struct GroupLayerNode: LayerNodeDefinition {
    static let layer = Layer.group
    
    static let inputDefinitions: LayerInputTypeSet = .init([
        .position,
        .size,
        .zIndex,
        .isClipped,
        .scale,
        .anchoring,
        .rotationX,
        .rotationY,
        .rotationZ,
        .opacity,
        .pivot,
        .orientation,
        .cornerRadius,
        .backgroundColor,
        .blur,
        .masks,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset,
        .spacingBetweenGridColumns,
        .spacingBetweenGridRows,
        .itemAlignmentWithinGridCell
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing)
        .union(.pinning)
        .union(.layerPaddingAndMargin)
        .union(.offsetInGroup)
        .union(.paddingAndSpacing)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool) -> some View {
        PreviewGroupLayer(
            document: document,
            graph: graph,
            layerViewModel: viewModel,
            layersInGroup: layersInGroup,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            position: viewModel.position.getPosition ?? .zero,
            size: viewModel.size.getSize ?? .defaultLayerGroupSize,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            isClipped: viewModel.isClipped.getBool ?? DEFAULT_GROUP_CLIP_SETTING,
            scale: viewModel.scale.getNumber ?? defaultScaleNumber,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            rotationX: viewModel.rotationX.asCGFloat,
            rotationY: viewModel.rotationY.asCGFloat,
            rotationZ: viewModel.rotationZ.asCGFloat,
            opacity: viewModel.opacity.getNumber ?? 1,
            pivot: viewModel.pivot.getAnchoring ?? .defaultPivot,
            orientation: viewModel.orientation.getOrientation ?? .defaultOrientation,
            spacing: viewModel.spacing.getStitchSpacing ?? .defaultStitchSpacing,
            cornerRadius: viewModel.cornerRadius.getNumber ?? .zero,
            blurRadius: viewModel.blur.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            backgroundColor: viewModel.backgroundColor.getColor ?? DEFAULT_GROUP_BACKGROUND_COLOR,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            gridData: viewModel.getGridData,
            stroke: viewModel.getLayerStrokeData())
    }
}

extension LayerSize {
    static let defaultLayerGroupSize = LayerSize(width: .fill, height: .fill)
}
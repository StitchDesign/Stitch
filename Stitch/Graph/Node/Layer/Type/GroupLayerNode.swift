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
import RealityKit

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

let DEFAULT_GROUP_SIZE = LayerSize(width: .fill, height: .fill)
let DEFAULT_GROUP_POSITION = CGSize.zero

let DEFAULT_GROUP_CLIP_SETTING: Bool = true

let DEFAULT_GROUP_PADDING: CGFloat = 0

let DEFAULT_GROUP_BACKGROUND_COLOR: Color = .clear

struct GroupLayerNode: LayerNodeDefinition {
    static let layer = Layer.group
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(layerInputs: Self.inputDefinitions,
              outputs: [.init(label: "Scroll Offset",
                              type: .position)],
              layer: Self.layer)
    }
    
    static let inputDefinitions: LayerInputPortSet = .init([
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
        .itemAlignmentWithinGridCell,
        
        // Layer scrolling via group layer
        .scrollContentSize,
        .isScrollAuto,
        
        .scrollXEnabled,
        .scrollJumpToXStyle,
        .scrollJumpToX,
        .scrollJumpToXLocation,
        
        .scrollYEnabled,
        .scrollJumpToYStyle,
        .scrollJumpToY,
        .scrollJumpToYLocation
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing)
        .union(.pinning)
        .union(.layerPaddingAndMargin)
        .union(.offsetInGroup)
        .union([.layerGroupAlignment])
        .union(.paddingAndSpacing)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        PreviewGroupLayer(
            document: document,
            graph: graph,
            layerViewModel: viewModel,
            realityContent: realityContent,
            layersInGroup: layersInGroup,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            position: viewModel.position.getPosition ?? .zero,
            size: viewModel.size.getSize ?? .defaultLayerGroupSize,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid,
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
            shadowColor: viewModel.shadowColor.getColor ?? .defaultShadowColor,
            shadowOpacity: viewModel.shadowOpacity.getNumber ?? .defaultShadowOpacity,
            shadowRadius: viewModel.shadowRadius.getNumber ?? .defaultShadowOpacity,
            shadowOffset: viewModel.shadowOffset.getPosition ?? .defaultShadowOffset,
            gridData: viewModel.getGridData,
            stroke: viewModel.getLayerStrokeData())
    }
}

extension LayerSize {
    static let defaultLayerGroupSize = LayerSize(width: .fill, height: .fill)
}

/*
 Inputs are extended to be as long as the longest loop on the *assigned layer*
 
 Eval modifies underlying layer view models.
 
 ?? When ScrollView.onScrollGeometry fires, we update the LayerViewModel's InteractiveLayer, then call the nativeScrollInteractionEval.
 */
@MainActor
func nativeScrollInteractionEval(node: NodeViewModel,
                                 state: GraphState) -> EvalResult {
    
    // log("nativeScrollInteractionEval: called")
    let defaultOutputs: PortValuesList =  [[.position(.zero)]]
    
    guard !node.outputs.isEmpty else {
        log("nativeScrollInteractionEval: initializing outputs")
        return .init(outputsValues: defaultOutputs)
    }
        
    return node.loopedEval(graphState: state,
                           layerNodeId: node.id) { layerViewModel, interactiveLayer, loopIndex in
        
        nativeScrollInteractionEvalOp(
            layerViewModel: layerViewModel,
            loopIndex: loopIndex,
            interactiveLayer: interactiveLayer,
            // TODO: DEC 3: grab parentSize from readSize of `assignedLayerNodeViewModel.layerGroupdId` ?
            parentSize: interactiveLayer.parentSize,
            currentGraphTime: state.graphStepState.graphTime,
            currentGraphFrameCount: state.graphStepState.graphFrameCount)
    }    
}

@MainActor
func nativeScrollInteractionEvalOp(layerViewModel: LayerViewModel, // for the group
                                   loopIndex: Int,
                                   interactiveLayer: InteractiveLayer,
                                   parentSize: CGSize,
                                   currentGraphTime: TimeInterval,
                                   currentGraphFrameCount: Int) -> PortValues {
    
    // log("nativeScrollInteractionEvalOp: called")
    
    // Update interactiveLayer according to inputs
    // Note: only update the properties that changed, else @Observable fires unnecessarily

    // Jump X
    let jumpToX = layerViewModel.scrollJumpToX.getPulse ?? .zero
    let newJumpToX = jumpToX == currentGraphTime
    if interactiveLayer.nativeScrollState.jumpToX != newJumpToX {
        interactiveLayer.nativeScrollState.jumpToX = newJumpToX
    }

    // Jump Y
    let jumpToY = layerViewModel.scrollJumpToY.getPulse ?? .zero
    let newJumpToY = jumpToY == currentGraphTime
    if interactiveLayer.nativeScrollState.jumpToY != newJumpToY {
        interactiveLayer.nativeScrollState.jumpToY = newJumpToY
    }
        
    // Graph reset
    let graphReset = Int(currentGraphFrameCount) == Int(2)
    if interactiveLayer.nativeScrollState.graphReset != graphReset {
        interactiveLayer.nativeScrollState.graphReset = graphReset
    }
    
    let offsetFromScrollView = interactiveLayer.nativeScrollState.rawScrollViewOffset
    
    return [
        .position(offsetFromScrollView)
    ]
}


struct NativeScrollNodeInputLocations {
    // The specific assigned layer (LayerNodeId)
    static let assignedLayer = 0

    static let xScrollEnabled = 1
    static let yScrollEnabled = 2

    static let contentSize = 3

    static let jumpStyleX = 4
    static let jumpToX = 5
    static let jumpPositionX = 6

    static let jumpStyleY = 7
    static let jumpToY = 8
    static let jumpPositionY = 9
}

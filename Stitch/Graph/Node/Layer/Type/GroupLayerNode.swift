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
        .scrollContentLayer,
        .scrollContentSize,
        
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
func nativeScrollInteractionEval(node: PatchNode,
                                 state: GraphDelegate) -> EvalResult {
    log("nativeScrollInteractionEval called")
    let defaultOutputs: PortValuesList =  [[.position(.zero)]]
    
    guard !node.outputs.isEmpty else {
        log("nativeScrollInteractionEval: initializing outputs")
        return .init(outputsValues: defaultOutputs)
    }
    
    guard let assignedLayerId: LayerNodeId = node.inputs.first?.first?.getInteractionId,
          let assignedLayerNode = state.getNodeViewModel(assignedLayerId.id),
          let assignedLayerNodeViewModel: LayerNodeViewModel = assignedLayerNode.layerNode else {
        log("nativeScrollInteractionEval: no assignedLayerId, assignedLayerNode and/or assignedLayerNodeViewModel for \(node.id)")
        return .init(outputsValues: defaultOutputs)
    }
        
    return node.loopedEval(graphState: state) { values, interactiveLayer, loopIndex in
        
        nativeScrollInteractionEvalOp(
            values: values,
            interactiveLayer: interactiveLayer,
            // TODO: DEC 3: grab parentSize from readSize of `assignedLayerNodeViewModel.layerGroupdId` ?
            parentSize: interactiveLayer.parentSize,
            currentGraphTime: state.graphStepState.graphTime,
            currentGraphFrameCount: state.graphStepState.graphFrameCount)
        
    }
    .toImpureEvalResult()
    
}

@MainActor
func nativeScrollInteractionEvalOp(values: PortValues,
                                   interactiveLayer: InteractiveLayer,
                                   parentSize: CGSize,
                                   currentGraphTime: TimeInterval,
                                   currentGraphFrameCount: Int) -> ImpureEvalOpResult {
    
    log("nativeScrollInteractionEvalOp called")
    // Update interactiveLayer according to inputs
    // Note: only update the properties that changed
    

    // Scroll enabled
    
    let xScrollEnabled = values[safe: NativeScrollNodeInputLocations.xScrollEnabled]?.getBool ?? NativeScrollInteractionNode.defaultScrollXEnabled
    let yScrollEnabled = values[safe: NativeScrollNodeInputLocations.yScrollEnabled]?.getBool ?? NativeScrollInteractionNode.defaultScrollYEnabled
    
    if interactiveLayer.nativeScrollState.xScrollEnabled != xScrollEnabled {
        interactiveLayer.nativeScrollState.xScrollEnabled = xScrollEnabled
    }
    if interactiveLayer.nativeScrollState.yScrollEnabled != yScrollEnabled {
        interactiveLayer.nativeScrollState.yScrollEnabled = yScrollEnabled
    }
    
    
    // Custom content size
    
    let contentSize = values[safe: NativeScrollNodeInputLocations.contentSize]?.getSize ?? .zero
    
    if interactiveLayer.nativeScrollState.contentSize != contentSize.asCGSize(parentSize) {
        interactiveLayer.nativeScrollState.contentSize = contentSize.asCGSize(parentSize)
    }
    
    
    // Jump X
    
    let jumpStyleX = values[safe: NativeScrollNodeInputLocations.jumpStyleX]?.getScrollJumpStyle ?? .scrollJumpStyleDefault
    let jumpToX = values[safe: NativeScrollNodeInputLocations.jumpToX]?.getPulse ?? .zero
    let jumpPositionX = values[safe: NativeScrollNodeInputLocations.jumpPositionX]?.getNumber ?? .zero
    
    if interactiveLayer.nativeScrollState.jumpStyleX != jumpStyleX {
        interactiveLayer.nativeScrollState.jumpStyleX = jumpStyleX
    }
    
    let newJumpToX = jumpToX == currentGraphTime
    if interactiveLayer.nativeScrollState.jumpToX != newJumpToX {
        interactiveLayer.nativeScrollState.jumpToX = newJumpToX
    }
    
    if interactiveLayer.nativeScrollState.jumpPositionX != jumpPositionX {
        interactiveLayer.nativeScrollState.jumpPositionX = jumpPositionX
    }
    
    
    // Jump Y
    
    let jumpStyleY = values[safe: NativeScrollNodeInputLocations.jumpStyleY]?.getScrollJumpStyle ?? .scrollJumpStyleDefault
    let jumpToY = values[safe: NativeScrollNodeInputLocations.jumpToY]?.getPulse ?? .zero
    let jumpPositionY = values[safe: NativeScrollNodeInputLocations.jumpPositionY]?.getNumber ?? .zero
    
    if interactiveLayer.nativeScrollState.jumpStyleY != jumpStyleY {
        interactiveLayer.nativeScrollState.jumpStyleY = jumpStyleY
    }
    
    let newJumpToY = jumpToY == currentGraphTime
    if interactiveLayer.nativeScrollState.jumpToY != newJumpToY {
        interactiveLayer.nativeScrollState.jumpToY = newJumpToY
    }
    
    if interactiveLayer.nativeScrollState.jumpPositionY != jumpPositionY {
        interactiveLayer.nativeScrollState.jumpPositionY = jumpPositionY
    }

    
    // Graph reset
    
    let graphReset = Int(currentGraphFrameCount) == Int(2)
    if interactiveLayer.nativeScrollState.graphReset != graphReset {
        interactiveLayer.nativeScrollState.graphReset = graphReset
    }
    
    let offsetFromScrollView = interactiveLayer.nativeScrollState.rawScrollViewOffset
    
    return .init(outputs: [
        .position(offsetFromScrollView)
    ])
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

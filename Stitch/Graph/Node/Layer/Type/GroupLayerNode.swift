//
//  GroupLayerNode.swift
//  prototype
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
        .union(.sizing).union(.pinning)
        .union(.paddingAndSpacing)
    
    static func content(graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, isGeneratedAtTopLevel: Bool,
                        parentDisablesPosition: Bool) -> some View {
        PreviewGroupLayer(
            graph: graph,
            layerViewModel: viewModel,
            layersInGroup: layersInGroup,
            isGeneratedAtTopLevel: isGeneratedAtTopLevel,
            interactiveLayer: viewModel.interactiveLayer,
            position: viewModel.position.getPosition ?? .zero,
            size: viewModel.size.getSize ?? defaultTextSize, // CGSize.zero,
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
            padding: viewModel.padding.getPadding ?? .defaultPadding,
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

extension GraphState {
    // Creates just the LayerNode itself;
    // does not add to SidebarGroups state etc.

    // When we create a GroupLayerNode, we must:
    // (1) determine its position and size
    //  based on its children's sizes and positions; and
    // (2) update the children's positions
    // ASSUMES: "Fit to Selection" mode.
    @MainActor
    func createGroupLayerNode(groupLayerData: SidebarLayerData,
                              // position of layer node on graph
                              position: CGPoint,
                              // z-height of layer node on graph
                              zIndex: ZIndex) -> NodeViewModel? {
        guard let children = groupLayerData.children else {
            fatalErrorIfDebug()
            return nil
        }

        let selectedNodes = children
            .flatMap { $0.allElementIds }
            .toSet

        let parentSize: CGSize = self.getParentSizeForSelectedNodes(selectedNodes: selectedNodes)

        // determine sise and position of group layer node,
        // plus how much  to adjust the position of any children inside.
        let layerGroupFit = self.getLayerGroupFit(
            selectedNodes,
            parentSize: parentSize)

        self.adjustGroupChildrenToLayerFit(
            layerGroupFit,
            selectedNodes)

        let newNode = Layer.group.graphNode.createViewModel(id: groupLayerData.id,
                                                            position: position,
                                                            zIndex: zIndex,
                                                            activeIndex: self.activeIndex,
                                                            graphDelegate: self)
        newNode.layerNode?.sizePort.rowObserver.allLoopedValues = [.size(layerGroupFit.size)]
        newNode.layerNode?.positionPort.rowObserver.allLoopedValues = [.position(layerGroupFit.position)]

        newNode.graphDelegate = self

        // Update selected nodes to report to new group node
        selectedNodes.forEach { nodeId in
            guard let layerNode = self.getNodeViewModel(nodeId)?.layerNode else {
                log("createGroupLayerNode: no node found")
                return
            }
            layerNode.layerGroupId = newNode.id
        }

        return newNode
    }
}

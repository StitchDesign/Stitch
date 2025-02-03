//
//  Model3DLayerNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 8/3/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SceneKit
import RealityKit

func retrieveBundleResource(forResource: String, withExtension: String = "usdz") -> URL {
    let urlPath = Bundle.main.url(forResource: forResource, withExtension: "usdz")
    return urlPath!
}

let default3DModelToyRobotAsset = retrieveBundleResource(forResource: "Vintage Toy Robot")

struct Model3DLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.model3D

    static let inputDefinitions: LayerInputPortSet = .init([
        .model3D,
        .anchorEntity,
        .position,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .transform3D,
        .isEntityAnimating,
        .translation3DEnabled,
        .scale3DEnabled,
        .rotation3DEnabled
    ])
        .union(.layerEffects)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        Preview3DModelLayer(
            document: document,
            graph: graph,
            layerViewModel: viewModel,
            realityContent: realityContent,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            entity: viewModel.mediaObject?.model3DEntity,
            anchorEntityId: viewModel.anchorEntity.anchorEntity,
            translation3DEnabled: viewModel.translation3DEnabled.getBool ?? false,
            rotation3DEnabled: viewModel.rotation3DEnabled.getBool ?? false,
            scale3DEnabled: viewModel.scale3DEnabled.getBool ?? false,
            position: viewModel.position.getPosition ?? .zero,
            rotationX: viewModel.rotationX.asCGFloat,
            rotationY: viewModel.rotationY.asCGFloat,
            rotationZ: viewModel.rotationZ.asCGFloat,
            size: viewModel.size.getSize ?? .zero,
            opacity: viewModel.opacity.asCGFloat,
            scale: viewModel.scale.asCGFloat,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            pivot: viewModel.pivot.getAnchoring ?? .defaultPivot,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid)
        .onChange(of: viewModel.mediaViewModel.currentMedia, initial: true) { oldValue, newValue in
            // Update transform for 3D model once loaded
            if oldValue != newValue,
               let model3DEntity = newValue?.mediaObject.model3DEntity {
                Self.updateTransform(entity: model3DEntity,
                                     layerViewModel: viewModel)
            }
        }
    }
    
    @MainActor
    static func updateTransform(entity: StitchEntity,
                                layerViewModel: LayerViewModel) {
        let transform = layerViewModel.transform3D.getTransform ?? .zero
        let matrix = simd_float4x4(position: transform.position3D,
                                   scale: transform.scale3D,
                                   rotation: transform.rotation3D)
        entity.applyMatrix(newMatrix: matrix)
    }
}

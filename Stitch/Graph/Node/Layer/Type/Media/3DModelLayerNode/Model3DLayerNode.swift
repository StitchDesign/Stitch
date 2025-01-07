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
// let airForceSneakersModelAsset = retrieveBundleResource(forResource: "AirForce Sneakers")
// let chairSwanModelAsset = retrieveBundleResource(forResource: "Chair")
// let cupSaucerSetModelAsset = retrieveBundleResource(forResource: "Cup Saucer Set")
// let fenderStratocasterSetModelAsset = retrieveBundleResource(forResource: "Fender Stratocaster")
// let flowerTulipModelAsset = retrieveBundleResource(forResource: "Flower Tulip")
// let gramophoneModelAsset = retrieveBundleResource(forResource: "Gramophone")
// let lemonPieModelAsset = retrieveBundleResource(forResource: "Lemon Meringue Pie")
// let pegasusTrailSneakersModelAsset = retrieveBundleResource(forResource: "Pegasus Trail Sneakers")
// let teapotModelAsset = retrieveBundleResource(forResource: "Teapot")
// let toyBiplaneModelAsset = retrieveBundleResource(forResource: "Toy Biplane")
// let toyCarModelAsset = retrieveBundleResource(forResource: "Toy Car")
// let toyDrummerModelAsset = retrieveBundleResource(forResource: "Toy Drummer")
// let retroTVModelAsset = retrieveBundleResource(forResource: "Retro TV")
// let wateringcanModelAsset = retrieveBundleResource(forResource: "Watering Can")

struct Model3DLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.model3D

    static let inputDefinitions: LayerInputPortSet = .init([
        .model3D,
        .anchorEntity,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset,
        .transform3D,
        .isEntityAnimating
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
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
                        realityContent: Binding<LayerRealityCameraContent?>) -> some View {
        Preview3DModelLayer(
            document: document,
            graph: graph,
            layerViewModel: viewModel,
            realityContent: realityContent,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            anchorEntityId: viewModel.anchorEntity.anchorEntity,
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
    }
}

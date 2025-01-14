//
//  BoxLayerNode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/13/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import RealityKit

struct BoxLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.box

    static let inputDefinitions: LayerInputPortSet = .init([
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
        .translation3DEnabled,
        .scale3DEnabled,
        .rotation3DEnabled,
        .cornerRadius,
        .isMetallic,
        .size3D
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)
    
    @MainActor
    private static func createEntity(color: Color,
                                     isMetallic: Bool,
                                     size3D: Point3D,
                                     cornerRadius: CGFloat) -> StitchEntity {
        let material = SimpleMaterial(color: color.toUIColor,
                                      isMetallic: isMetallic)
        
        let entity = Entity()
        
        // Create a mesh resource.
        let boxMesh = MeshResource.generateBox(width: Float(size3D.x),
                                               height: Float(size3D.y),
                                               depth: Float(size3D.z),
                                               cornerRadius: Float(cornerRadius))
        
        // Add the mesh resource to a model component, and add it to the entity.
        entity.components.set(ModelComponent(mesh: boxMesh, materials: [material]))
        
        return StitchEntity(type: .box, entity: entity)
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
            entity: Self.createEntity(color: viewModel.color.getColor ?? .red,
                                      isMetallic: viewModel.isMetallic.getBool ?? false,
                                      size3D: viewModel.size3D.getPoint3D ?? .zero,
                                      cornerRadius: viewModel.cornerRadius.getNumber ?? .zero),
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
    }
}

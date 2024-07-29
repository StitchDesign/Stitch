//
//  PreviewRealityLayer.swift
//  Stitch
//
//  Created by Nicholas Arner on 1/15/23.
//

import SwiftUI
import RealityKit
import StitchSchemaKit

struct PreviewRealityLayer: View {
    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerViewModel
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool

    var body: some View {
        let nodeId = self.viewModel.id.layerNodeId.id
        let position = viewModel.position.getPosition ?? .zero
        let rotationX = viewModel.rotationX.asCGFloat
        let rotationY = viewModel.rotationY.asCGFloat
        let rotationZ = viewModel.rotationZ.asCGFloat
        let layerSize = self.viewModel.size.getSize ?? default3DModelLayerSize
        let size = layerSize.asCGSize(parentSize)
        let anchoring = viewModel.anchoring.getAnchoring ?? .defaultAnchoring
        let scale = viewModel.scale.asCGFloat

        switch graph.cameraFeedManager {
        case .loaded(let cameraFeedManager):
            if let cameraFeedManager = cameraFeedManager.cameraFeedManager,
               let node = graph.getNodeViewModel(viewModel.id.layerNodeId.asNodeId) {
                @Bindable var node = node
                
                RealityLayerView(graph: graph,
                                 node: node, 
                                 layerViewModel: viewModel,
                                 cameraFeedManager: cameraFeedManager,
                                 interactiveLayer: self.viewModel.interactiveLayer,
                                 allAnchors: viewModel.allAnchors.compactMap { $0.asyncMedia },
                                 position: position,
                                 rotationX: rotationX,
                                 rotationY: rotationY,
                                 rotationZ: rotationZ,
                                 size: size,
                                 layerSize: layerSize,
                                 scale: scale,
                                 opacity: viewModel.opacity.asCGFloat,
                                 anchoring: anchoring,
                                 isCameraFeedEnabled: viewModel.isCameraEnabled.getBool ?? false,
                                 isShadowsEnabled: viewModel.isShadowsEnabled.getBool ?? false,
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
                                 parentDisablesPosition: parentDisablesPosition)
                    .onAppear {
                        // Update list of node Ids using camera
                        cameraFeedManager.enabledNodeIds.insert(nodeId)
                    }
            } else {
                EmptyView()
                    .onAppear {
                        #if DEBUG
                        fatalError()
                        #endif
                    }
            }

        case .loading, .failed:
            EmptyView()

        case .none:
            // Note that EmptyView won't trigger the onApppear closure
            Color.clear
                .onAppear {
                    dispatch(RealityViewCreatedWithoutCamera(nodeId: nodeId))
                }
        }
    }
}

struct RealityLayerView: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let layerViewModel: LayerViewModel

    let cameraFeedManager: CameraFeedManager
    let interactiveLayer: InteractiveLayer
    let allAnchors: [GraphMediaValue]
    let position: CGSize
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: CGSize
    let layerSize: LayerSize
    let scale: CGFloat
    let opacity: CGFloat
    let anchoring: Anchoring
    let isCameraFeedEnabled: Bool
    let isShadowsEnabled: Bool
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
            if let arView = cameraFeedManager.arView,
                !graph.isGeneratingProjectThumbnail {
                RealityView(arView: arView,
                            size: layerSize,
                            scale: scale,
                            opacity: opacity,
                            isCameraEnabled: isCameraFeedEnabled,
                            isShadowsEnabled: isShadowsEnabled)
                .onChange(of: allAnchors, initial: true) { _, newAnchors in
                    let mediaList = newAnchors.map { $0.mediaObject }
                    
                    // Update entities in ar view
                    arView.updateAnchors(mediaList: mediaList)
                }
            } else {
                EmptyView()
            }
        }
        .modifier(PreviewCommonModifier(
            graph: graph,
            layerViewModel: layerViewModel,
            interactiveLayer: interactiveLayer,
            position: position,
            rotationX: rotationX,
            rotationY: rotationY,
            rotationZ: rotationZ,
            size: layerSize,
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
            parentDisablesPosition: parentDisablesPosition))
    }
}

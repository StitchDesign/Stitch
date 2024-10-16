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
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerViewModel
    
    let isPinnedViewRendering: Bool
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
        
        switch document.cameraFeedManager {
        case .loaded(let cameraFeedManager):
            if let cameraFeedManager = cameraFeedManager.cameraFeedManager,
               let node = document.visibleGraph.getNodeViewModel(viewModel.id.layerNodeId.asNodeId) {
                @Bindable var node = node
                
                RealityLayerView(document: document,
                                 graph: graph,
                                 node: node,
                                 layerViewModel: viewModel,
                                 cameraFeedManager: cameraFeedManager, 
                                 isPinnedViewRendering: isPinnedViewRendering,
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
                    graph.enabledCameraNodeIds.insert(nodeId)
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
                    document.realityViewCreatedWithoutCamera(graph: graph,
                                                             nodeId: nodeId)
                }
        }
    }
}

struct RealityLayerView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let layerViewModel: LayerViewModel
    
    let cameraFeedManager: CameraFeedManager
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let allAnchors: [GraphMediaValue]
    let position: CGPoint
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
            if isPinnedViewRendering, // Can't run multiple reality views
               let arView = cameraFeedManager.arView,
               !document.isGeneratingProjectThumbnail {
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
                Color.clear
            }
        }
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

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
    let layersInGroup: LayerDataList
    let isPinnedViewRendering: Bool
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool
    
    var body: some View {
        let position = viewModel.position.getPosition ?? .zero
        let rotationX = viewModel.rotationX.asCGFloat
        let rotationY = viewModel.rotationY.asCGFloat
        let rotationZ = viewModel.rotationZ.asCGFloat
        let layerSize = self.viewModel.size.getSize ?? default3DModelLayerSize
        let size = layerSize.asCGSize(parentSize)
        let anchoring = viewModel.anchoring.getAnchoring ?? .defaultAnchoring
        let scale = viewModel.scale.asCGFloat
        let cameraDirection = viewModel.cameraDirection.getCameraDirection ?? .back
        
        if let node = document.visibleGraph.getNodeViewModel(viewModel.id.layerNodeId.asNodeId) {
            @Bindable var node = node
            
            RealityLayerView(document: document,
                             graph: graph,
                             node: node,
                             layerViewModel: viewModel,
                             layersInGroup: self.layersInGroup,
                             cameraFeedManager: document.cameraFeedManager?.loadedInstance?.cameraFeedManager,
                             isPinnedViewRendering: isPinnedViewRendering,
                             interactiveLayer: self.viewModel.interactiveLayer,
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
                             cameraDirection: cameraDirection,
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
                             parentDisablesPosition: parentDisablesPosition,
                             parentIsScrollableGrid: parentIsScrollableGrid)
        } else {
            EmptyView()
                .onAppear {
#if DEBUG
                    fatalError()
#endif
                }
        }
    }
}

struct RealityLayerView: View {    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var layerViewModel: LayerViewModel
    let layersInGroup: LayerDataList
    let cameraFeedManager: CameraFeedManager?
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
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
    let cameraDirection: CameraDirection
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
    let parentIsScrollableGrid: Bool
    
    // Override camera setting on Mac
    var _isCameraEnabled: Bool {
#if targetEnvironment(macCatalyst)
        return false
#else
        return isCameraFeedEnabled
#endif
    }
    
    @ViewBuilder
    var realityView: some View {
        // Can't run multiple reality views
        if !isPinnedViewRendering || document.isGeneratingProjectThumbnail {
            Color.clear
        }
        
        else if _isCameraEnabled {
            switch document.cameraFeedManager {
            case .loaded(let cameraFeedManager):
                if let cameraFeedManager = cameraFeedManager.cameraFeedManager,
                   let arView = cameraFeedManager.arView {
                    CameraRealityView(arView: arView,
                                      size: layerSize,
                                      scale: scale,
                                      opacity: opacity,
                                      isShadowsEnabled: isShadowsEnabled)
                    .onAppear {
                        // Update list of node Ids using camera
                        graph.enabledCameraNodeIds.insert(node.id)
                        
                        self.layerViewModel.realityContent = arView
                    }
                    .onDisappear {
                        self.layerViewModel.realityContent = nil
                    }
                }
                
            case .loading, .failed:
                EmptyView()
                
            case .none:
                Color.clear
#if !targetEnvironment(macCatalyst)
                    .onAppear {
                        // Cannot accidentally call this multiple times!
                        if isPinnedViewRendering {
                            let nodeId = self.layerViewModel.id.layerNodeId.id
                            document.realityViewCreatedWithoutCamera(graph: graph,
                                                                     nodeId: nodeId,
                                                                     realityCameraDirection: self.cameraDirection)
                        }
                    }
#endif
                
            }
        }
        
        else {
            NonCameraRealityView(size: layerSize,
                                 scale: scale,
                                 opacity: opacity,
                                 isShadowsEnabled: isShadowsEnabled) { arView in
                self.layerViewModel.realityContent = arView
            }
                                 .onDisappear {
                                     self.layerViewModel.realityContent = nil
                                 }
        }
    }
    
    var body: some View {
        ZStack {
            realityView
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
                    parentDisablesPosition: parentDisablesPosition,
                    parentIsScrollableGrid: parentIsScrollableGrid))
                
            GroupLayerNode.content(document: document,
                                   graph: graph,
                                   viewModel: layerViewModel,
                                   parentSize: parentSize,
                                   layersInGroup: layersInGroup,
                                   isPinnedViewRendering: isPinnedViewRendering,
                                   parentDisablesPosition: parentDisablesPosition,
                                   parentIsScrollableGrid: parentIsScrollableGrid,
                                   realityContent: self.$layerViewModel.realityContent)
        }
    }
}

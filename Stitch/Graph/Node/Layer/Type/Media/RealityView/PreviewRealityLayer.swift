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
        
        if let node = document.visibleGraph.getNodeViewModel(viewModel.id.layerNodeId.asNodeId) {
            @Bindable var node = node
            
            RealityLayerView(document: document,
                             graph: graph,
                             node: node,
                             layerViewModel: viewModel,
                             cameraFeedManager: document.cameraFeedManager?.loadedInstance?.cameraFeedManager,
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
    let layerViewModel: LayerViewModel
    
    let cameraFeedManager: CameraFeedManager?
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
    let parentIsScrollableGrid: Bool
    
    // Override camera setting on Mac
    var _isCameraEnabled: Bool {
#if targetEnvironment(macCatalyst)
        return false
#else
        return isCameraFeedEnabled
#endif
    }
    
    var body: some View {
        Group {
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
                        }
                        .onChange(of: allAnchors, initial: true) { _, newAnchors in
                            let mediaList = newAnchors.map { $0.mediaObject }
                            
                            // Update entities in ar view
                            arView.updateAnchors(mediaList: mediaList)
                        }
                    }

                case .loading, .failed:
                    EmptyView()

                case .none:
                    Color.clear
#if !targetEnvironment(macCatalyst)
                        .onAppear {
                            let nodeId = self.layerViewModel.id.layerNodeId.id
                            document.realityViewCreatedWithoutCamera(graph: graph,
                                                                     nodeId: nodeId)
                        }
#endif
                    
                }
            }
            
            else {
                NonCameraRealityView(size: layerSize,
                                     scale: scale,
                                     opacity: opacity,
                                     isShadowsEnabled: isShadowsEnabled,
                                     anchors: allAnchors)
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
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid))
    }
}

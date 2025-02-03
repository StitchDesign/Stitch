//
//  RealityNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 1/15/23.
//

import RealityKit
import SwiftUI
import StitchSchemaKit

struct RealityViewLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.realityView
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .cameraDirection,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .isCameraEnabled,
        .isShadowsEnabled,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)

        static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
    
    @MainActor
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        // Create reality view if reality layer AND no reality content is created at this hierarchy
        if let realityContent = realityContent {
            GroupLayerNode.content(document: document,
                                   graph: graph,
                                   viewModel: viewModel,
                                   parentSize: parentSize,
                                   layersInGroup: layersInGroup,
                                   isPinnedViewRendering: isPinnedViewRendering,
                                   parentDisablesPosition: parentDisablesPosition,
                                   parentIsScrollableGrid: parentIsScrollableGrid,
                                   realityContent: realityContent)
            .eraseToAnyView()
        }
        
        // ONLY create a reality view session if none yet made
        else {
            PreviewRealityLayer(document: document,
                                graph: graph,
                                viewModel: viewModel,
                                layersInGroup: layersInGroup,
                                isPinnedViewRendering: isPinnedViewRendering,
                                parentSize: parentSize,
                                parentDisablesPosition: parentDisablesPosition,
                                parentIsScrollableGrid: parentIsScrollableGrid)
            .eraseToAnyView()
        }
    }
}

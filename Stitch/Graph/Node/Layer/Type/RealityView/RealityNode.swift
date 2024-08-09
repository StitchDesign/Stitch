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
    
    static let inputDefinitions: LayerInputTypeSet = .init([
        .allAnchors,
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
        .union(.sizing).union(.pinning)

        static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
    
    static func content(graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, isGeneratedAtTopLevel: Bool,
                        parentDisablesPosition: Bool) -> some View {
        PreviewRealityLayer(graph: graph,
                            viewModel: viewModel,
                            isGeneratedAtTopLevel: isGeneratedAtTopLevel,
                            parentSize: parentSize,
                            parentDisablesPosition: parentDisablesPosition)
    }
}

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
    
    static let inputDefinitions: LayerInputTypeSet = [
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
        .blurRadius,
        .blendMode,
        .brightness,
        .colorInvert,
        .contrast,
        .hueRotation,
        .saturation,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ]

        static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
    
    static func content(graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        parentDisablesPosition: Bool) -> some View {
        PreviewRealityLayer(graph: graph,
                            viewModel: viewModel,
                            parentSize: parentSize,
                            parentDisablesPosition: parentDisablesPosition)
    }
}

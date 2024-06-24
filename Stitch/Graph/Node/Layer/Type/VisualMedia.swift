//
//  VisualMedia.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct ImageLayerNode: LayerNodeDefinition {
    static let layer = Layer.image
    
    static let inputDefinitions: LayerInputTypeSet = [
        .image,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .fitStyle,
        .scale,
        .anchoring,
        .zIndex,
        .clipped,
        .blurRadius,
        .blendMode,
        .brightness,
        .colorInvert,
        .contrast,
        .hueRotation,
        .saturation,
        .masks,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ]
    
    static func content(graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        parentDisablesPosition: Bool) -> some View {
        VisualMediaLayerView(graph: graph,
                             viewModel: viewModel,
                             parentSize: parentSize,
                             parentDisablesPosition: parentDisablesPosition)
    }
    
        static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

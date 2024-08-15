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
    
    static let inputDefinitions: LayerInputTypeSet = .init([
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
        .masks,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning)
    
    static func content(graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isGeneratedAtTopLevel: Bool,
                        parentDisablesPosition: Bool) -> some View {
        VisualMediaLayerView(graph: graph,
                             viewModel: viewModel,
                             isGeneratedAtTopLevel: isGeneratedAtTopLevel,
                             parentSize: parentSize,
                             parentDisablesPosition: parentDisablesPosition)
    }
    
        static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

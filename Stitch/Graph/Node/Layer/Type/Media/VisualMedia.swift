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
    
    static let inputDefinitions: LayerInputPortSet = .init([
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
        .union(.sizing)
        .union(.pinning)
        .union(.layerPaddingAndMargin)
        .union(.offsetInGroup)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        VisualMediaLayerView(document: document,
                             graph: graph,
                             viewModel: viewModel,
                             isPinnedViewRendering: isPinnedViewRendering,
                             parentSize: parentSize,
                             parentDisablesPosition: parentDisablesPosition,
                             parentIsScrollableGrid: parentIsScrollableGrid)
    }
    
        static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

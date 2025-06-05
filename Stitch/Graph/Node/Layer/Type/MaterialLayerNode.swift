//
//  MaterialLayerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/16/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct MaterialLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.material

    static let inputDefinitions: LayerInputPortSet = .init([
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .pivot,
        .masks,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset,
        .materialThickness,
        .deviceAppearance
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
        
        PreviewMaterialLayer(document: document,
                             graph: graph,
                             viewModel: viewModel,
                             parentSize: parentSize,
                             isPinnedViewRendering: isPinnedViewRendering,
                             parentDisablesPosition: parentDisablesPosition,
                             parentIsScrollableGrid: parentIsScrollableGrid)
    }
}

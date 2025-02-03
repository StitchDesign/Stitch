//
//  SphereLayerNode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/16/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import RealityKit

struct SphereLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.sphere

    static let inputDefinitions: LayerInputPortSet = .init([
        .anchorEntity,
        .position,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .transform3D,
        .translation3DEnabled,
        .scale3DEnabled,
        .rotation3DEnabled,
        .isMetallic,
        .radius3D,
        .color
    ])
        .union(.layerEffects)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        Model3DLayerNode
            .content(document: document,
                     graph: graph,
                     viewModel: viewModel,
                     parentSize: parentSize,
                     layersInGroup: layersInGroup,
                     isPinnedViewRendering: isPinnedViewRendering,
                     parentDisablesPosition: parentDisablesPosition,
                     parentIsScrollableGrid: parentIsScrollableGrid,
                     realityContent: realityContent)
            .model3DModifier(viewModel: viewModel,
                             entityType: .sphere,
                             isPinnedViewRendering: isPinnedViewRendering)
    }
}

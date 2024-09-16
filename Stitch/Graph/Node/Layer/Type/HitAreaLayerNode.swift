//
//  HitAreaLayerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/13/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let defaultHitAreaSize = LayerSize(width: 50,
                                   height: 50)

struct HitAreaLayerNode: LayerNodeDefinition {
    static var layer: Layer = .hitArea
    
    static let inputDefinitions: LayerInputTypeSet = .init([
        .enabled,
        .position,
        .size,
        .anchoring,
        .zIndex,
        .setupMode
    ])
        .union(.aspectRatio)
        .union(.sizing).union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)
    
    static func content(document: StitchDocumentViewModel,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool) -> some View {
        PreviewHitAreaLayer(
            graph: graph,
            layerViewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            position: viewModel.position.getPosition ?? .zero,
            size: viewModel.size.getSize ?? defaultHitAreaSize,
            enabled: viewModel.enabled.getBool ?? true,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            setupMode: viewModel.setupMode.getBool ?? false,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition)
    }
}

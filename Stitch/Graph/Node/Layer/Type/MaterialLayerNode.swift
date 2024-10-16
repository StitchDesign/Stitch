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

    static let inputDefinitions: LayerInputTypeSet = .init([
        .shape,
        .color,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .coordinateSystem,
        .pivot,
        .masks,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList,
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool) -> some View {
        Text("love")
    }
}

//
//  RectangleNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension Color {
    static let defaultShadowColor = Color.black
}

extension StitchPosition {
    static let defaultPosition: Self = .zero
}

// TODO: what is the common parent of Double and Float ?
extension Double {
    static let defaultScale = 1.0
    static let defaultOpacity = 1.0
    
    // Shadows
    static let defaultShadowOpacity = 0.0
    static let defaultShadowRadius = 1.0
}

extension CGFloat {
    static let defaultScale = 1.0
    static let defaultOpacity = 1.0
    
    // Shadow
    static let defaultShadowOpacity = 0.0
    static let defaultShadowRadius = 1.0
}

extension StitchPosition {
    static let defaultShadowOffset = Self.zero
}

struct RectangleLayerNode: LayerNodeDefinition {
    static let layer = Layer.rectangle
    
    static let inputDefinitions: LayerInputPortSet = .init([
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
            .cornerRadius,
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
                        realityContent: Binding<LayerRealityCameraContent?>) -> some View {
        ShapeLayerView(document: document,
                       graph: graph,
                       viewModel: viewModel,
                       isPinnedViewRendering: isPinnedViewRendering,
                       parentSize: parentSize,
                       parentDisablesPosition: parentDisablesPosition,
                       parentIsScrollableGrid: parentIsScrollableGrid)
    }
}

//
//  OvalNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let defaultStrokeWidth: CGFloat = 4.0

/*
 .brightness(0) // identity
 .saturation(1) // identity
 .contrast(1) // identity
 .hueRotation(Angle(degrees: 0)) // identity
 */
extension Double {
    static let defaultBrightnessForLayerEffect: Double = 0
    static let defaultSaturationForLayerEffect: Double = 1
    static let defaultContrastForLayerEffect: Double = 1
    static let defaultHueRotationForLayerEffect: Double = 0
}

extension Bool {
    static let defaultColorInvertForLayerEffect: Bool = false
}

struct OvalLayerNode: LayerNodeDefinition {
    static let layer = Layer.oval
        
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
        ShapeLayerView(document: document,
                       graph: graph,
                       viewModel: viewModel,
                       isPinnedViewRendering: isPinnedViewRendering,
                       parentSize: parentSize,
                       parentDisablesPosition: parentDisablesPosition)
    }
}

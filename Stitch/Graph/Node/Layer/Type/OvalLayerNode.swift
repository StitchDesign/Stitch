//
//  OvalNode.swift
//  prototype
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
        
    static let inputDefinitions: LayerInputTypeSet =
    [
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
        .strokePosition,
        .strokeWidth,
        .strokeColor,
        .strokeStart,
        .strokeEnd,
        .strokeLineCap,
        .strokeLineJoin,
        .blurRadius,
        .blendMode,
        .brightness,
        .colorInvert,
        .contrast,
        .hueRotation,
        .saturation,
        .pivot,
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
        ShapeLayerView(graph: graph,
                       viewModel: viewModel,
                       parentSize: parentSize,
                       parentDisablesPosition: parentDisablesPosition)
    }
}

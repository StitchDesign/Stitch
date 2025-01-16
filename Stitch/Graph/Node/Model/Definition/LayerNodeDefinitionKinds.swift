//
//  LayerGraphNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/21/24.
//

import Foundation
import StitchSchemaKit

extension Layer {
    var graphNode: (any NodeDefinition.Type) {
        self.layerGraphNode as (any NodeDefinition.Type)
    }
    
    var layerGraphNode: (any LayerNodeDefinition.Type) {
        switch self {
        case .text:
            return TextLayerNode.self
        case .oval:
            return OvalLayerNode.self
        case .rectangle:
            return RectangleLayerNode.self
        case .image:
            return ImageLayerNode.self
        case .group:
            return GroupLayerNode.self
        case .video:
            return VideoLayerNode.self
        case .model3D:
            return Model3DLayerNode.self
        case .realityView:
            return RealityViewLayerNode.self
        case .shape:
            return ShapeLayerNode.self
        case .colorFill:
            return ColorFillLayerNode.self
        case .hitArea:
            return HitAreaLayerNode.self
        case .canvasSketch:
            return CanvasSketchLayerNode.self
        case .textField:
            return TextFieldLayerNode.self
        case .map:
            return MapLayerNode.self
        case .progressIndicator:
          return ProgressIndicatorLayerNode.self
        case .switchLayer:
          return SwitchLayerNode.self
        case .linearGradient:
          return LinearGradientLayerNode.self
        case .radialGradient:
            return RadialGradientLayerNode.self
        case .angularGradient:
            return AngularGradientLayerNode.self
        case .sfSymbol:
            return SFSymbolLayerNode.self
        case .videoStreaming:
            return VideoStreamingLayerNode.self
        case .material:
            return MaterialLayerNode.self
        case .box:
            return BoxLayerNode.self
        case .sphere:
            return SphereLayerNode.self
        case .cylinder:
            return CylinderLayerNode.self
        case .cone:
            return ConeLayerNode.self
        }
    }
}

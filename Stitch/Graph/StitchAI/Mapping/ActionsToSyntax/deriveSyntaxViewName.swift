//
//  deriveSyntaxViewName.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/26/25.
//

import Foundation

extension Layer {
    
    func deriveSyntaxViewName(layerGroupOrientiation: StitchOrientation? = nil) -> SyntaxViewName? {
        
        switch self {
        
            // Stitch Layer.sfSymbol and Stitch Layer.image both use SwiftUI Image
        case .sfSymbol, .image:
            return .image
        case .rectangle:
            return .rectangle
        case .oval:
            return .ellipse
        case .text:
            return .text
        case .textField:
            return .textField
        
        // TODO: JUNE 24: Layer.group becomes ZStack, VStack, HStack, Grid etc. according to LayerInputPort.orientation
        case .group:
            // default to VStack for groups (any stack/grid maps to .group)
            return .zStack
        
        case .map:
            return .map
        case .video:
            return .videoPlayer
        case .model3D:
            return .model3D
        case .linearGradient:
            return .linearGradient
        case .radialGradient:
            return .radialGradient
        case .angularGradient:
            return .angularGradient
        case .material:
            return .material
        case .canvasSketch:
            return .canvas
        case .realityView:
            return nil
        case .shape:
            return nil
        case .colorFill:
            return .color
        case .hitArea:
            return .color
        case .progressIndicator:
            return nil
        case .switchLayer:
            return .toggle
        case .videoStreaming:
            return .videoPlayer
        case .box, .sphere, .cylinder, .cone:
            return .model3D
        }
    }
}

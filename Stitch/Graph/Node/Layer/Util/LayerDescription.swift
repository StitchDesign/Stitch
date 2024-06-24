//
//  LayerDescription.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/23.
//

import Foundation
import StitchSchemaKit

extension Layer {
    var nodeDescription: String {
        // Add new line
        "\n\(self.nodeDescriptionBody)"
    }

    var nodeDescriptionBody: String {
        switch self {
        case .text:
            return textDescription
        case .oval:
            return ovalDescription
        case .rectangle:
            return rectangleDescription
        case .image:
            return imageDescription
        case .group:
            return groupDescription
        case .video:
            return videoDescription
        case .model3D:
            return model3DDescription
        case .realityView:
            return realityViewDescription
        case .shape:
            return shapeDescription
        case .colorFill:
            return colorFillDescription
        case .hitArea:
            return hitAreaDescription
        case .canvasSketch:
            return canvasSketchDescription
        case .textField:
            return textFieldDescription
        case .map:
            return mapDescription
        case .progressIndicator:
            return progressIndicatorDescription
        case .switchLayer:
            return switchDescription
        case .linearGradient:
            return linearGradientDescription
        case.radialGradient:
            return radialGradientDescription
        case .angularGradient:
            return angularGradientDescription
        case .sfSymbol:
            return sfSymbolDescription
        case .videoStreaming:
            return videoStreamingDescription
        }
    }
}

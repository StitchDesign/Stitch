//
//  LayerEvalExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/2/24.
//

import Foundation
import StitchSchemaKit

extension Layer {
    @MainActor
    var evaluate: PureEvals? {
        switch self {
        case .canvasSketch:
            return .node(canvasSketchEval)
        case .textField:
            return .node(textFieldLayerEval)
        case .switchLayer:
            return .graphStep(switchLayerEval)
        case .group:
            return .graph(nativeScrollInteractionEval)
        default:
            return nil
        }
    }
}

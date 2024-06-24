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
    var evaluate: EvaluationStyle? {
        switch self {
        case .canvasSketch:
            return .pure(.node(canvasSketchEval))
        case .textField:
            return .pure(.node(textFieldLayerEval))
        case .switchLayer:
            return .pure(.graphStep(switchLayerEval))
        case .oval, .rectangle, .image, .group, .video, .realityView, .shape, .colorFill, .hitArea, .map:
            return nil
        default:
            return nil
        }
    }
}

// puts string edit from text-field layer view model into the text-field layer node's output (by index)
@MainActor
func textFieldLayerEval(node: NodeViewModel) -> EvalResult {

    guard let layerNodeViewModel = node.layerNode,
          layerNodeViewModel.layer == .textField else {
        fatalErrorIfDebug()
        return .init(outputsValues: [])
    }
    
    let textFieldLayerViewModels = layerNodeViewModel.previewLayerViewModels

    let evalOp: OpWithIndex<PortValue> = { _, loopIndex in

        // Note: on the initial evaluation of this layer node, we will not have yet have any `textFieldLayerViewModels`. That's fine; the node eval works fine afterward.
        let textFieldValueAtIndex = textFieldLayerViewModels[safe: loopIndex]?.text.getString?.string ?? ""

        // log("textFieldLayerEval: values: \(values)")
        // log("textFieldLayerEval: loopIndex: \(loopIndex)")
        // log("textFieldLayerEval: textFieldValueAtIndex: \(textFieldValueAtIndex)")

        return PortValue.string(.init(textFieldValueAtIndex))
    }

    let newOutput = loopedEval(node: node, evalOp: evalOp)
    // log("textFieldLayerEval: newOutput: \(newOutput)")

    return .init(outputsValues: [newOutput])
}


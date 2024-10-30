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


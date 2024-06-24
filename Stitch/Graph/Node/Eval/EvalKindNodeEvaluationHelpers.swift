//
//  EvalKindNodeEvaluationHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

typealias PureEval = (PortValues) -> PortValues
typealias OutputsOnlyPureEvalT<T: PatchNodeTypeSet> = (PortValuesList, T) -> PortValuesList
typealias NTGetter<T: PatchNodeTypeSet> = (PatchNodeViewModel) -> T?

@MainActor
func outputsOnlyEvalT<T: PatchNodeTypeSet>(_ eval: @escaping OutputsOnlyPureEvalT<T>,
                                           _ ntGetter: @escaping NTGetter<T>) -> PureNode {

    return { (node: PatchNode) -> EvalResult in
        guard let patchNode = node.patchNode,
              let evalKind = ntGetter(patchNode) else {
            #if DEBUG
            fatalError()
            #endif
            return EvalResult(outputsValues: node.outputs)
        }

        let newOutputValues: PortValuesList = eval(
            node.inputs,
            evalKind)

        return .init(outputsValues: newOutputValues)
    }
}

@MainActor
let pureNodeEval = { (_ eval: @escaping PureEval) in { (node: PatchNode) in
    let outputsValues = loopedEval(inputsValues: node.inputs, outputsValues: node.outputs) { values, _ in
        eval(values)
    }
    .remapOutputs()

    return EvalResult(outputsValues: outputsValues)
}
}

@MainActor let numberEval = { (_ eval: @escaping OutputsOnlyPureEvalT<NumberNodeType>) in
    outputsOnlyEvalT(eval, \.asNumberEval)
}

@MainActor let arithmeticNodeTypeEval = { (_ eval: @escaping OutputsOnlyPureEvalT<ArithmeticNodeType>) in
    outputsOnlyEvalT(eval, \.asArithmeticEval)
}

@MainActor let mathNodeTypeEval = { (_ eval: @escaping OutputsOnlyPureEvalT<MathNodeType>) in
    outputsOnlyEvalT(eval, \.asMathEval)
}

// Default helper for now
let stringOp: Operation = { (_: PortValues) -> PortValue in .string(.init("")) }

func resultsMaker(_ inputs: PortValuesList,
                  outputs: PortValuesList = []) -> (Operation) -> PortValuesList {
    return { (op: Operation) in
        [outputEvalHelper(inputs: inputs,
                          outputs: outputs,
                          operation: op)]
    }
}

func resultsMaker2(_ inputs: PortValuesList,
                   outputs: PortValuesList = []) -> (Operation2) -> PortValuesList {
    return { (op: Operation2) in
        outputEvalHelper2(inputs: inputs,
                          outputs: outputs,
                          operation: op)
    }
}

func resultsMaker3(_ inputs: PortValuesList,
                   outputs: PortValuesList = []) -> (Operation3) -> PortValuesList {
    return { (op: Operation3) in
        outputEvalHelper3(inputs: inputs,
                          outputs: outputs,
                          operation: op)
    }
}

func resultsMaker4(_ inputs: PortValuesList,
                   outputs: PortValuesList = []) -> (Operation4) -> PortValuesList {
    return { (op: Operation4) in
        outputEvalHelper4(inputs: inputs,
                          outputs: outputs,
                          operation: op)
    }
}

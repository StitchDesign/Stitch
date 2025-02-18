//
//  OperationEvaluationHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/6/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/* ----------------------------------------------------------------
 Evaluation Helpers
 - e.g. take Inputs and return some [non-port-value type]
 - e.g. turning Inputs into Outputs
 ---------------------------------------------------------------- */

// given call args (port values for that index),
// produces result (new port value)
typealias Operation = @MainActor (PortValues) -> PortValue
typealias ComputedOperation = (PortValues, ComputedNodeState) -> PortValue

// e.g. sizeUnpack returns two values for two separate outputs
typealias Operation2 = (PortValues) -> (PortValue, PortValue)

// e.g. point3D returns three values for three separate outputs
typealias Operation3 = (PortValues) -> (PortValue, PortValue, PortValue)

// e.g. ColorToHSL node, ColorToRGBA
typealias Operation4 = (PortValues) -> (PortValue, PortValue, PortValue, PortValue)

typealias PortValueTuple8 = (PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue)
typealias Operation8 = (PortValues, Int) -> PortValueTuple8
typealias Operation9 = (PortValues) -> (PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue)

typealias Operation10 = (PortValues) -> (PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue)


// mostly commonly used; for node evals that produce 1 output
@MainActor
func outputEvalHelper(inputs: PortValuesList,
                      outputs: PortValuesList,// these will be extended,
                      operation: Operation) -> PortValues {
    createOutputCallbackLoop(inputs: inputs,
                             outputs: outputs) { operation($0) }
}

@MainActor
func createOutputCallbackLoop(inputs: PortValuesList,
                              outputs: PortValuesList,
                              callback: (PortValues) -> PortValue) -> PortValues {

    var singleOutputLoop: PortValues = []

    let (longestLoopLength,
         adjustedInputs) = getMaxCountAndLengthenedArrays(inputs,
                                                          outputs)

    (0..<longestLoopLength).forEach { (index: Int) in

        // callArgs are the inputs we need to call the eval-fn;
        // we construct these inputs based on the current loop index we're on

        // so e.g. if node's inputs are:
        // input0: [0, 1, 2]
        // input1: [0, 10, 20]

        // then call args are:
        // [0, 0] for index 0
        // [1, 10] for index 1
        // [2, 20] for index 2

        // and so we have:
        // singleOutputLoop.append(operation([0, 0])) for index 0
        // singleOutputLoop.append(operation([1, 10])) for index 1
        // and so on...

        // The operation produces a single result (PortValue) for that index position/slot.

        let callArgs = adjustedInputs.map { $0[index] }
        let x: PortValue = callback(callArgs)
        singleOutputLoop.append(x)
    }

    return singleOutputLoop
}

// Input vs. Extensible Inputs:
// eg. optionPicker's first port is never extended,
// whereas we may need to extend the rest of the ports.

// ^^^ DOES THIS MATTER? What's wrong with extending the first port of optionPicker? You'd just be repeating the same number -- shouldn't matter.

// option
@MainActor
func outputEvalHelper(input: PortValues,
                      extensibleInputs: PortValuesList,
                      operation: Operation) -> PortValues {

    var singleOutputLoop: PortValues = []

    // extensible inputs must be at least as long the inextensible
    // and the indices we iterate through the inextensible ones

    let longestLoopLength: Int = getLongestLoopLength([input])

    // we extend only the extensible inputs
    let adjustedInputs: PortValuesList = extensibleInputs.map { (values: [PortValue]) -> PortValues in
        lengthenArray(loop: values, length: longestLoopLength)
    }

    (0..<longestLoopLength).forEach { (index: Int) in

        var callArgs: PortValues = []
        ([input] + adjustedInputs).forEach { (input: PortValues) in
            callArgs.append(input[index])
        }

        let x: PortValue = operation(callArgs)
        singleOutputLoop.append(x)
    }

    return singleOutputLoop
}

// only used by sizeUnpack
@MainActor
func outputEvalHelper2(inputs: PortValuesList,
                       outputs: PortValuesList,
                       operation: Operation2) -> PortValuesList {

    var firstOutputLoop: PortValues = []
    var secondOutputLoop: PortValues = []

    let (longestLoopLength, adjustedInputs) = getMaxCountAndLengthenedArrays(inputs,
                                                                             outputs)

    (0..<longestLoopLength).forEach { (index: Int) in

        var callArgs: PortValues = []

        adjustedInputs.forEach { (input: PortValues) in
            callArgs.append(input[index])
        }

        let x: (PortValue, PortValue) = operation(callArgs)
        firstOutputLoop.append(x.0)
        secondOutputLoop.append(x.1)
    }

    return [firstOutputLoop, secondOutputLoop]
}

@MainActor
func outputEvalHelper3(inputs: PortValuesList,
                       outputs: PortValuesList,
                       operation: Operation3) -> PortValuesList {

    var firstOutputLoop: PortValues = []
    var secondOutputLoop: PortValues = []
    var threeOutputLoop: PortValues = []

    let (longestLoopLength, adjustedInputs) = getMaxCountAndLengthenedArrays(inputs,
                                                                             outputs)

    (0..<longestLoopLength).forEach { (index: Int) in

        var callArgs: PortValues = []

        adjustedInputs.forEach { (input: PortValues) in
            callArgs.append(input[index])
        }

        let x: (PortValue, PortValue, PortValue) = operation(callArgs)
        firstOutputLoop.append(x.0)
        secondOutputLoop.append(x.1)
        threeOutputLoop.append(x.2)
    }

    return [firstOutputLoop, secondOutputLoop, threeOutputLoop]
}

@MainActor
func outputEvalHelper4(inputs: PortValuesList,
                       outputs: PortValuesList,
                       operation: Operation4) -> PortValuesList {

    var firstOutputLoop: PortValues = []
    var secondOutputLoop: PortValues = []
    var threeOutputLoop: PortValues = []
    var fourthOutputLoop: PortValues = []

    let (longestLoopLength, adjustedInputs) = getMaxCountAndLengthenedArrays(inputs,
                                                                             outputs)

    (0..<longestLoopLength).forEach { (index: Int) in

        var callArgs: PortValues = []

        adjustedInputs.forEach { (input: PortValues) in
            callArgs.append(input[index])
        }

        let x: (PortValue, PortValue, PortValue, PortValue) = operation(callArgs)
        firstOutputLoop.append(x.0)
        secondOutputLoop.append(x.1)
        threeOutputLoop.append(x.2)
        fourthOutputLoop.append(x.3)
    }

    return [firstOutputLoop, secondOutputLoop, threeOutputLoop, fourthOutputLoop]
}


@MainActor
func outputEvalHelper9(inputs: PortValuesList,
                        outputs: PortValuesList,
                        operation: Operation9) -> PortValuesList {

    var firstOutputLoop: PortValues = []
    var secondOutputLoop: PortValues = []
    var threeOutputLoop: PortValues = []
    var fourthOutputLoop: PortValues = []
    var fifthOutputLoop: PortValues = []
    var sixthOutputLoop: PortValues = []
    var seventhOutputLoop: PortValues = []
    var eighthOutputLoop: PortValues = []
    var ninthOutputLoop: PortValues = []

    let (longestLoopLength, adjustedInputs) = getMaxCountAndLengthenedArrays(inputs,
                                                                             outputs)

    (0..<longestLoopLength).forEach { (index: Int) in

        var callArgs: PortValues = []

        adjustedInputs.forEach { (input: PortValues) in
            callArgs.append(input[index])
        }

        let x: (PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue) = operation(callArgs)
        firstOutputLoop.append(x.0)
        secondOutputLoop.append(x.1)
        threeOutputLoop.append(x.2)
        fourthOutputLoop.append(x.3)
        fifthOutputLoop.append(x.4)
        sixthOutputLoop.append(x.5)
        seventhOutputLoop.append(x.6)
        eighthOutputLoop.append(x.7)
        ninthOutputLoop.append(x.8)
    }

    return [firstOutputLoop, secondOutputLoop, threeOutputLoop, fourthOutputLoop, fifthOutputLoop, sixthOutputLoop, seventhOutputLoop, eighthOutputLoop, ninthOutputLoop]
}

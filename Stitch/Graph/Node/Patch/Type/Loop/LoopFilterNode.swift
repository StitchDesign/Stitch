//
//  LoopFilterNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/7/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// TODO: `input` input can be many different node-types
@MainActor
func loopFilterNode(id: NodeId,
                    position: CGSize = .zero,
                    zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Input", [.string(.init(""))]), // 0
        ("Include", [.number(1)]) // 1
    )

    // loop Builder has TWO outputs:
    // 1. indices: ALWAYS a loop of ints, where each int is just an index
    // 2. values: a loop of the user-chosen value-type (here: color)

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        // it's called index, but it's actually the loop that's coming out
        values:
            ("Loop", [.string(.init(""))]),
        ("Index", [.number(0)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .loopFilter,
        userVisibleType: .string,
        inputs: inputs,
        outputs: outputs)
}

func loopFilterEval(inputs: PortValuesList,
                    outputs: PortValuesList) -> PortValuesList {

    // What if inputLoop and includeLoop aren't same length?
    let inputLoop: PortValues = inputs.first!
    let includeLoop: [Int] = inputs[1].map { Int($0.getNumber ?? 0.0) }

    let longestLoopLength: Int = getLongestLoopLength(inputs)
    let extendedInputLoop = lengthenArray(loop: inputLoop,
                                          length: longestLoopLength)
    let extendedIncludeLoop = lengthenArray(loop: includeLoop,
                                            length: longestLoopLength)

    //    log("loopFilterEval: inputLoop: \(inputLoop)")
    //    log("loopFilterEval: includeLoop: \(includeLoop)")
    //    log("loopFilterEval: longestLoopLength: \(longestLoopLength)")
    //    log("loopFilterEval: extendedInputLoop: \(extendedInputLoop)")
    //    log("loopFilterEval: extendedIncludeLoop: \(extendedIncludeLoop)")

    let result = loopFilter(input: extendedInputLoop,
                            include: extendedIncludeLoop,
                            originalInputLoopLength: inputLoop.count)

    //    log("loopFilterEval: result: \(result)")

    // If the result is empty, then we should return a default false result.
    if result.isEmpty {
        let emptyResult = [inputLoop.first!.defaultFalseValue]
        return [emptyResult, emptyResult.asLoopIndices]
    } else {
        return [result, result.asLoopIndices]
    }
}

// `input` can be any PortValue
func loopFilter(input: [PortValue],
                include: [Int],
                originalInputLoopLength: Int) -> [PortValue] {

    var result = [PortValue]()

    /*
     For each index i +item n in the include-loop,
     find the input-loop's item k at the same index i,
     and add k n-many times to the result loop.

     Example:
     input-loop = [apple, carrot, orange]
     include-loop = [1, 0, 1]
     result = [apple, orange]

     Example:
     input-loop = [apple]
     include-loop = [5]
     result = [apple, apple, apple, apple, apple]

     Example:
     input-loop = [apple, carrot, orange]
     include-loop = [0, 3, 1]
     result = [carrot, carrot, carrot, orange]
     */
    for (includeIndex, includeItem) in include.enumerated() {
        // Mod by original input length
        let inputValueAtIndex = input[includeIndex % originalInputLoopLength]
        (0..<includeItem).forEach { _ in
            result.append(inputValueAtIndex)
        }
    }
    return result
}

// TODO:
/*
 TODO:
 - move to test file
 - add tests for
 */
struct LoopFilter_REPL_View: View {

    static let apple = PortValue.string(.init("apple"))
    static let carrot = PortValue.string(.init("carrot"))
    static let orange = PortValue.string(.init("orange"))

    //    var loopFilter1: Bool {
    var loopFilter1: [PortValue] {
        let inputLoop = [PortValue.string(.init("apple")), .string(.init("carrot")), .string(.init("orange"))]
        let includeLoop = [1, 0, 1]
        //        let expected = [PortValue.string(.init("apple")), .string(.init("orange"))]
        return loopFilter(input: inputLoop, include: includeLoop, originalInputLoopLength: inputLoop.count)
    }

    var loopFilter2: [PortValue] {
        let inputLoop = [PortValue.string(.init("apple"))]
        let includeLoop = [5]
        //        let expected = [PortValue.string(.init("apple")), .string(.init("apple")), .string(.init("apple")), .string(.init("apple")), .string(.init("apple"))]
        return loopFilter(input: inputLoop, include: includeLoop, originalInputLoopLength: inputLoop.count)
    }

    var loopFilter3: [PortValue] {
        let inputLoop = [PortValue.string(.init("apple")), .string(.init("carrot")), .string(.init("orange"))]
        let includeLoop = [0, 3, 1]
        //        let expected = [PortValue.string("carrot"), .string("carrot"), .string("carrot"), .string("orange")]
        return loopFilter(input: inputLoop, include: includeLoop, originalInputLoopLength: inputLoop.count)
    }

    var loopFilter4: [PortValue] {
        //        let inputLoop = [PortValue.number(0), .number(1), .number(2)]
        let inputLoop = [PortValue.number(0), .number(1), .number(2), .number(6)]
        let includeLoop = [0, 0, 1]
        //        let includeLoop = [0, 0, 1, 2]
        return loopFilter(input: inputLoop,
                          include: includeLoop,
                          originalInputLoopLength: inputLoop.count)
    }

    var body: some View {
        VStack {
            //            Text("hello")
            //            Text("loopFilter1: \(loopFilter1.description)")
            //            Text("loopFilter2: \(loopFilter2.description)")
            //            Text("loopFilter3: \(loopFilter3.description)")
            Text("loopFilter4: \(loopFilter4.description)")
        }
    }
}

struct LoopFilter_REPL_View_Previews: PreviewProvider {
    static var previews: some View {
        LoopFilter_REPL_View()
    }
}

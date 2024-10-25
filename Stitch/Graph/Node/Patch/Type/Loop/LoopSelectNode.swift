//
//  LoopSelectNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func loopSelectNode(id: NodeId,
                    position: CGSize = .zero,
                    zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Input", [.string(.init(""))]), // 0
        ("Index Loop", [.number(0)]) // 1
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
        patchName: .loopSelect,
        userVisibleType: .string,
        inputs: inputs,
        outputs: outputs)
}

func loopSelectEval(inputs: PortValuesList,
                    outputs: PortValuesList) -> PortValuesList {

    // operates at the level of loops (rather than 'value-at-index of a loop'),
    // and so we can't use op, etc.

    let valueLoop: PortValues = inputs.first!
    let indexLoop: PortValues = inputs[1]

    let longestLoopLength: Int = getLongestLoopLength(inputs)
    let adjustedValueLoop = lengthenArray(loop: valueLoop, length: longestLoopLength)
    let adjustedIndexLoop = lengthenArray(loop: indexLoop, length: longestLoopLength)

    // The Index Loop input's values could be [7, 8, 9],
    // i.e. indices we don't have;
    // so we mod those values by the length of the original,
    // unextended valueLoop.
    let valueLoopLength = valueLoop.count

    //                log("loopSelectEval: longestLoopLength: \(longestLoopLength)")
    //                log("loopSelectEval: valueLoop: \(valueLoop)")
    //                log("loopSelectEval: indexLoop: \(indexLoop)")
    //                log("loopSelectEval: adjustedValueLoop: \(adjustedValueLoop)")
    //                log("loopSelectEval: adjustedIndexLoop: \(adjustedIndexLoop)")
    //                log("loopSelectEval: valueLoopLength: \(valueLoopLength)")

    var outputLoop: PortValues = adjustedIndexLoop
        .map { Int($0.getNumber!) }
        .asLoopFriendlyIndices(valueLoopLength)
        //            .asLoopInsertFriendlyIndices(valueLoopLength)
        //            .map { adjustedValueLoop[$0 % valueLoopLength] }
        .map { adjustedValueLoop[$0] }

    //                log("loopSelectEval: outputLoop: \(outputLoop)")
    //                log("loopSelectEval: outputLoop.asLoopIndices: \(outputLoop.asLoopIndices)")

    let outputLoopCount = outputLoop.count
    let indexLoopCount = indexLoop.count

    // Outputs cannot be longer than index-loop input
    outputLoop = outputLoop.dropLast(outputLoopCount - indexLoopCount)

    return [outputLoop, outputLoop.asLoopIndices]
}

extension Double {
    var toInt: Int {
        Int(self)
    }
}

extension [Int] {
    // get loop friendly index = any int that is negative or larger than original loop length, becomes an index that is positive and LTE original loop length
    func asLoopFriendlyIndices(_ originalLoopLength: Int) -> [Int] {
        self.map { n in
            var n = n
            if n < 0 {
                while n < 0 {
                    n += originalLoopLength
                }
                return n
            } else {
                return n % originalLoopLength
            }
        }
    }

    /*
     // original length = 3
     // self = [-1]
     n = -1
     */

    func asLoopInsertFriendlyIndices(_ originalLoopLength: Int) -> [Int] {
        Stitch.getLoopInsertFriendlyIndices(self, originalLoopLength)
    }
}

func getLoopInsertFriendlyIndices(_ loop: [Int],
                                  _ originalLoopLength: Int) -> [Int] {
    loop.map { n in
        var n = n
        if n < 0 {
            while n < 0 {
                n += (originalLoopLength + 1)
            }
            return n
        } else {
            return n % originalLoopLength
        }
    }
}

struct LoopSelect_REPL_View: View {

    var body: some View {

        let loopInsertFriendlyIndices = getLoopInsertFriendlyIndices([-1], 3) // 3
        //        let loopInsertFriendlyIndices = getLoopInsertFriendlyIndices([-2], 3) // 2
        //        let loopInsertFriendlyIndices = getLoopInsertFriendlyIndices([-3], 3) // 1
        //        let loopInsertFriendlyIndices = getLoopInsertFriendlyIndices([-4], 3) // 0
        //        let loopInsertFriendlyIndices = getLoopInsertFriendlyIndices([-5], 3) // 3
        //        let loopInsertFriendlyIndices = getLoopInsertFriendlyIndices([-6], 3) // 2
        //        let loopInsertFriendlyIndices = getLoopInsertFriendlyIndices([-7], 3) // 1

        var xs = ["a", "b", "c"]
        //        let _ = xs.insert("x", at: 0) // insert at front
        //        let _ = xs.insert("x", at: 1) // insert after first item
        //        let _ = xs.insert("x", at: 2) // insert before last element
        //                let _ = xs.insert("x", at: 3) // inserts at end

        VStack(spacing: 4) {
            Text("loopInsertFriendlyIndices: \(loopInsertFriendlyIndices.description)")
            Text("xs: \(xs.description)")
            Divider()
            Text("-1 % 3 = \(-1 % 3)")
            Text("-2 % 3 = \(-2 % 3)")
            Text("-3 % 3 = \(-3 % 3)")
            Text("-4 % 3 = \(-4 % 3)")
            Text("-5 % 3 = \(-5 % 3)")
            Text("-7 % 3 = \(-7 % 3)")
            Text("-8 % 3 = \(-8 % 3)")
        }.scaleEffect(1.5)
    }

}

struct LoopSelect_REPL_View_Previews: PreviewProvider {
    static var previews: some View {
        LoopSelect_REPL_View()
    }
}

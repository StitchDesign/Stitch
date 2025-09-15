//
//  LoopFilterNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/7/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LoopFilterPatchNode: PatchNodeDefinition {
    static let patch = Patch.loopFilter
    static let defaultUserVisibleType: UserVisibleType? = .string

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.string(.init(""))],
                    label: "Input"
                ),
                .init(
                    defaultValues: [.number(1)],
                    label: "Include"
                )
            ],
            outputs: [
                .init(
                    label: "Loop",
                    type: type ?? .string
                ),
                .init(
                    label: "Index",
                    type: .number
                )
            ]
        )
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

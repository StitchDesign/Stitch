//
//  LoopSelectNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LoopSelectNode: PatchNodeDefinition {
    static let patch: Patch = .loopSelect
    
    private static let _defaultUserVisibleType: UserVisibleType = .string
    
    // overrides protocol
    static let defaultUserVisibleType: UserVisibleType? = Self._defaultUserVisibleType
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(label: "Input",
                  defaultType: Self._defaultUserVisibleType),
            .init(label: "Index Loop",
                  staticType: .number)
        ],
              outputs: [
                .init(label: "Loop", type: Self._defaultUserVisibleType),
                .init(label: "Index", type: .number)
              ])
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaReferenceObserver()
    }
    
    @MainActor
    static func evaluate(node: NodeViewModel) -> EvalResult? {
        let inputs = node.inputs
        let defaultOutputs = node.defaultOutputs
        
        guard //let mediaObserver = node.ephemeralObservers?.first as? MediaReferenceObserver,
              let valueLoop: PortValues = inputs.first,
              let indexLoop: PortValues = inputs[safe: 1] else {
            fatalErrorIfDebug()
            return .init(outputsValues: [defaultOutputs])
        }
        
        // operates at the level of loops (rather than 'value-at-index of a loop'),
        // and so we can't use op, etc.
        
        let longestLoopLength: Int = getLongestLoopLength(inputs)
        let adjustedValueLoop = lengthenArray(loop: valueLoop, length: longestLoopLength)
        let adjustedIndexLoop = lengthenArray(loop: indexLoop, length: longestLoopLength)
        
        // The Index Loop input's values could be [7, 8, 9],
        // i.e. indices we don't have;
        // so we mod those values by the length of the original,
        // unextended valueLoop.
        let valueLoopLength = valueLoop.count
        
        let indexLoopCount = indexLoop.count
        
        // Match output loop count with indexLoopCount. We pass in fake values to match media observers with output loop count.
        let fakeValuesLoop: PortValues = (0..<indexLoopCount)
            .map { PortValue.number(Double($0)) }
        
        return node.loopedEval(MediaReferenceObserver.self,
                               inputsValuesList: [fakeValuesLoop]) { _, mediaObserver, loopIndex in
            guard let inputLoopIndex = adjustedIndexLoop[safe: loopIndex]?.getInt else {
                return MediaEvalOpResult(from: defaultOutputs)
            }
            
            // Protects divide by 0
            guard valueLoopLength != 0 else {
                fatalErrorIfDebug()
                return .init(from: defaultOutputs)
            }
            
            // Use mod to wrap selected index if input exceeds length
            var modInputIndex = inputLoopIndex % valueLoopLength
            
            // Use positive index if mod creates negative result
            if modInputIndex < 0 {
                modInputIndex += valueLoopLength
            }
            
            guard let value = adjustedValueLoop[safe: modInputIndex] else {
                return MediaEvalOpResult(from: defaultOutputs)
            }
            
            return Self.createMediaEvalOp(value: value,
                                          selectedLoopIndex: modInputIndex,
                                          outputLoopIndex: loopIndex,
                                          node: node)
        }
    }
    
    @MainActor
    private static func createMediaEvalOp(value: PortValue,
                                          selectedLoopIndex: Int,
                                          outputLoopIndex: Int,
                                          node: NodeViewModel) -> MediaEvalOpResult {
        let outputs = [value, .number(Double(outputLoopIndex))]
        if let mediaValue = value.asyncMedia,
           let mediaObject = node.getInputMediaValue(portIndex: 0,
                                                     loopIndex: selectedLoopIndex,
                                                     mediaId: mediaValue.id) {
            return .init(values: outputs,
                         media: mediaObject)
        }
        
        return MediaEvalOpResult(from: outputs)
    }
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

        let xs = ["a", "b", "c"]
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

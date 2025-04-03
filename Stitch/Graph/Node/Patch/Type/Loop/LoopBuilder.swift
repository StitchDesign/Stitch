//
//  LoopBuilder.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/13/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LoopBuilderNode: PatchNodeDefinition {
    static let patch: Patch = .loopBuilder
    
    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(label: "", defaultType: .number),
            .init(label: "", defaultType: .number),
            .init(label: "", defaultType: .number),
            .init(label: "", defaultType: .number),
            .init(label: "", defaultType: .number)
        ], outputs: [
            .init(label: "Index",
                  type: .number),
            .init(label: "Values",
                  type: type ?? Self.defaultUserVisibleType ?? .number)
        ])
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
    
    static let defaultOutputs: PortValuesList = [[.number(0)],
                                                 [.number(0)]]
}

func buildIndicesLoop(loop: PortValues) -> PortValues {
    loop.indices.map(\.toDouble).map(PortValue.number)
}

extension PortValues {
    var asLoopIndices: PortValues {
        buildIndicesLoop(loop: self)
    }

    // Better?: make a PortValue `Hashable`
    // https://stackoverflow.com/questions/25738817/removing-duplicate-elements-from-an-array-in-swift
    var unique: PortValues {
        var uniqueValues = PortValues()
        for value in self {
            if uniqueValues.doesNotContain(value) {
                uniqueValues.append(value)
            }
        }
        return uniqueValues
    }

    func flattenValues() -> Self {
        guard let firstValue = self.first else {
            return []
        }

        return [firstValue]
    }
}

@MainActor
func loopBuilderEval(node: PatchNode,
                     graphStep: GraphStepState) -> ImpureEvalResult {
    
    let flattenedInputs: PortValues = node.inputs.map { values in
        // loopBuilder turns loops into a single falsey value
        let valueForIndex = values.count > 1 ? values.first!.defaultFalseValue : values.first!
        return valueForIndex
    }
    
    let result = node.loopedEval(MediaEvalOpObserver.self,
                           inputsValuesList: [flattenedInputs]) { (values, mediaObserver, index) -> MediaEvalOpResult in
        assertInDebug(values.first != nil)
        
        // index of our loop
        let indexPortValue = PortValue.number(Double(index))
        
        // looped value
        let value = values.first ?? .number(.zero)
        
        switch node.userVisibleType {
        case .media:
            guard let inputMediaValue = values.first?.asyncMedia,
//                  // MARK: loop and port index are flipped
//                  let mediaObject = node.getInputMediaValue(portIndex: 0,
//                                                            loopIndex: index,
//                                                            mediaId: inputMediaValue.id) else {
                    let mediaObject = mediaObserver.inputMedia else {
                return .init(from: [indexPortValue,
                                    .asyncMedia(nil)])
            }
            
            let asyncMedia = AsyncMediaValue(id: .init(),
                                             dataType: .computed,
                                             label: inputMediaValue.label)
            return .init(values: [indexPortValue,
                                  .asyncMedia(asyncMedia)],
                         media: mediaObject)
            
        default:
            return .init(from: [indexPortValue, value])
        }
    }
                           .createPureEvalResult(node: node)
    
    return result
}


// MARK: eval implementation below creates unique media object copies, which may not be needed given a loop builder doesn't mutate media objects at all.

//// LoopBuilder expects its inputs to be non-loops.
//@MainActor
//func loopBuilderEval(node: PatchNode,
//                     graphStep: GraphStepState) -> ImpureEvalResult {
//    
//    let flattenedInputs: PortValues = node.inputs.map { values in
//        // loopBuilder turns loops into a single falsey value
//        let valueForIndex = values.count > 1 ? values.first!.defaultFalseValue : values.first!
//        return valueForIndex
//    }
//
//    guard node.userVisibleType == .media else {
//        // Handles-non media scenarios purely
//        let newOutputs: PortValuesList = [flattenedInputs.asLoopIndices,
//                                          flattenedInputs]
//        
//        return .init(outputsValues: newOutputs)
//    }
//    
//    // Handles creating unique media objects
//    return node.loopedEval(MediaEvalOpObserver.self,
//                           inputsValuesList: [flattenedInputs]) { (values, mediaObserver, index) -> MediaEvalOpResult in
//        mediaObserver.asyncMediaEvalOp(loopIndex: index,
//                                       values: values) { [weak mediaObserver] in
//            let indexPortValue = PortValue.number(Double(index))
//
//            guard let inputMediaValue = values.first?.asyncMedia,
//                  let mediaCopy = await mediaObserver?.getUniqueMedia(inputMediaValue: inputMediaValue,
//                                                                      // loop and port index are flipped
//                                                                      inputPortIndex: index,
//                                                                      loopIndex: 0) else {
//                return .init(from: [indexPortValue,
//                                    .asyncMedia(nil)])
//            }
//            
//            let asyncMedia = AsyncMediaValue(id: .init(),
//                                             dataType: .computed,
//                                             label: inputMediaValue.label)
//            return .init(values: [indexPortValue,
//                                  .asyncMedia(asyncMedia)],
//                         media: mediaCopy)
//        }
//    }
//                           .createPureEvalResult(node: node)
//}

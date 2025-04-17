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
    
    let result = node.getLoopedEvalResults(MediaEvalOpObserver.self,
                                           inputsValuesList: [flattenedInputs]) { (values, mediaObserver, index) -> MediaEvalOpResult in
        assertInDebug(values.first != nil)
        
        // index of our loop
        let indexPortValue = PortValue.number(Double(index))
        
        // looped value
        let value = values.first ?? .number(.zero)
        
        switch node.userVisibleType {
        case .media:
            guard let inputMediaValue = values.first?.asyncMedia else {
                return .init(from: [indexPortValue,
                                    .asyncMedia(nil)])
            }
            
            guard let mediaObject = mediaObserver.inputMedia,
                  mediaObject.id == inputMediaValue.id else {
                // If media value exists but no object then likely a scenario where media was directly imported here--this requires an async step to load media
                Task(priority: .high) { [weak mediaObserver, weak node] in
                    if await mediaObserver?
                        .getUniqueMedia(inputMediaValue: inputMediaValue,
                                        inputPortIndex: index,
                                        loopIndex: 0) != nil {
                        // Recalculate this node on next graph step
                        node?.calculate()
                    }
                }
                
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

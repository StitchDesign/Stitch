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

// LoopBuilder expects its inputs to be non-loops.
@MainActor
func loopBuilderEval(node: PatchNode,
                     graphStep: GraphStepState) -> ImpureEvalResult {
    
    let flattenedInputs: PortValues = node.inputs.map { values in
        // loopBuilder turns loops into a single falsey value
        let valueForIndex = values.count > 1 ? values.first!.defaultFalseValue : values.first!
        return valueForIndex
    }

    
    guard node.userVisibleType == .media else {
        // Handles-non media scenarios purely
        let newOutputs: PortValuesList = [flattenedInputs.asLoopIndices,
                                          flattenedInputs]
        
        return .init(outputsValues: newOutputs)
    }
    
    guard let asyncEvalObserver = node.ephemeralObservers?.first as? MediaEvalOpObserver else {
        fatalErrorIfDebug()
        return .init(outputsValues: LoopBuilderNode.defaultOutputs)
    }

    // Remap inputs so that all values enter eval as a single loop
    let remappedInputs = [flattenedInputs].remapOutputs()
    
    // Handles creating unique media objects
    return loopedEval(inputsValues: remappedInputs) { values, _ in
        // Create task for background handling
        Task(priority: .userInitiated) { [weak node] in
            guard let node = node else {
                return
            }
            
            let opResult = await LoopBuilderNode.copyMedia(values: values)
            
            await MainActor.run { [weak node] in
                guard let node = node else {
                    fatalErrorIfDebug()
                    return
                }

                node.graphDelegate?.recalculateGraph(outputValues: .all(opResult),
                                                     nodeId: node.id,
                                                     loopIndex: 0)
            }
        }
        
        // Return default nil values until loop is complete with copied media
        let nilValues: PortValues = values.map { _ in PortValue.asyncMedia(nil) }
        return AsyncMediaOutputs.all([flattenedInputs.asLoopIndices, nilValues])
    }
        .toImpureEvalResult()
}

extension LoopBuilderNode {
    static func copyMedia(values: PortValues) async -> PortValuesList {
        var newOutputs: PortValues = []
        
        for value in values {
            guard let inputMedia = value.asyncMedia else {
                  // We use loop as the port ID since the values have been flattened
                  // And the actual loop index is always 0
                newOutputs.append(.asyncMedia(nil))
                continue
            }
            
            do {
                let copiedMedia = try await inputMedia.mediaObject.createComputedCopy()
                
                if let copiedMedia = copiedMedia {
                    let graphMedia = GraphMediaValue(computedMedia: copiedMedia)
                    newOutputs.append(graphMedia.portValue)
                } else {
                    newOutputs.append(.asyncMedia(nil))
                }
            } catch {
                fatalErrorIfDebug()
                newOutputs.append(.asyncMedia(nil))
            }
        }
        
        return [values.asLoopIndices, newOutputs]
    }
}

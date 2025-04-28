//
//  LoopFilter.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/14/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let fakeIndex = -1.0

struct LoopInsertNode: PatchNodeDefinition {
    static let patch = Patch.loopInsert

    static let defaultUserVisibleType: UserVisibleType? = .color

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.color(.red), .color(.yellow), .color(.blue), .color(.green)],
                    label: "Loop"
                ),
                .init(
                    defaultValues: [.color(.purple)],
                    label: "Value"
                ),
                .init(
                    label: "Index",
                    staticType: .number
                ),
                .init(
                    label: "Insert",
                    staticType: .pulse
                )
            ],
            outputs: [
                .init(
                    label: "Loop",
                    type: type ?? .color
                ),
                .init(
                    label: "Index",
                    type: .number
                )
            ]
        )
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        // If we have existing inputs, then we're deserializing,
        // and should base internal state and starting outputs on those inputs.
        LoopingEphemeralObserver()
    }
}

final class LoopingEphemeralObserver: MediaEvalOpObservable {
    @MainActor var previousValues: PortValues = []
    @MainActor var currentLoadingMediaId: UUID?
    let mediaActor: MediaEvalOpCoordinator = .init()
    @MainActor let mediaViewModel: MediaViewModel = .init()
    
    // Holds media object if new value is media
    @MainActor var mediaListToBeInserted: [GraphMediaValue?] = []
    
    weak var nodeDelegate: NodeViewModel?
    
    @MainActor init() { }
}

extension LoopingEphemeralObserver {
    @MainActor
    func onPrototypeRestart(document: StitchDocumentViewModel) {
        self.previousValues = []
    }
}

extension PortValues {
    var unwrapAsPulses: [TimeInterval] {
        let asPulses = self.compactMap(\.getPulse)
        if asPulses.count != self.count {
            log("PortValues extension: unwrapAsPulses: could not unwrap", .logToServer)
            return self.map { $0.getPulse ?? .zero }
        }
        return asPulses
    }

    // Did at least one index in this loop pulse?
    func someIndexPulsed(_ graphTime: TimeInterval) -> Bool {
        self.unwrapAsPulses.contains { $0.shouldPulse(graphTime) }
    }
}

// TODO: revisit how this works with indices
@MainActor
func loopInsertEval(node: PatchNode,
                    graphStep: GraphStepState) -> EvalResult {
    loopModificationNodeEval(node: node,
                             graphStep: graphStep)
}

@MainActor
func loopModificationNodeEval(node: PatchNode,
                              graphStep: GraphStepState) -> EvalResult {
    guard let computedStates = node.ephemeralObservers as? [LoopingEphemeralObserver],
          let computedState = computedStates.first else {
        fatalErrorIfDebug()
        return .init(outputsValues: node.defaultOutputsList)
    }

    let isInsert = node.kind.getPatch == .loopInsert
    let defaultFirstInputs: PortValues = [.color(.red), .color(.yellow), .color(.blue), .color(.green)]

    //if the outputs are empty (when we reset/open a graph); just provide the inputs instead
    //outputs = inputs
    //to match origimai
    
    let inputsValues: PortValuesList = node.inputs
    var existingMediaList: [GraphMediaValue?]? = node.userVisibleType == .media ? computedStates.map(\.inputMedia) : nil
    let newMediaListToInsert = computedState.mediaListToBeInserted
    var outputsValues: PortValuesList = node.outputs
    
    let firstOutput: PortValues? = outputsValues.first
    
    if (firstOutput?.isEmpty == true) || (firstOutput?.first == nil) {
        outputsValues = inputsValues
    }
    
    let graphTime = graphStep.graphTime

    // Apparently: If ANY indices pulsed, then we insert.
    let shouldPulse: Bool = (inputsValues[safe: isInsert ? 3 : 2] ?? []).contains { value in
        value.getPulse?.shouldPulse(graphTime) ?? false
    }

    let currentInput = inputsValues.first ?? defaultFirstInputs
    let currentInputLoop: PortValues = currentInput
    let previousInputLoop: PortValues = computedState.previousValues
    let inputLoopChanged = currentInputLoop != previousInputLoop

    // Update previous inputs
    computedState.previousValues = currentInput

    //    log("loopInsertEval: currentInputLoop: \(currentInputLoop)")
    //    log("loopInsertEval: nodeComputedState.previousValues: \(nodeComputedState.previousValues)")
    //    log("loopInsertEval: previousInputLoop: \(previousInputLoop)")


    let shouldEval = shouldPulse || inputLoopChanged


    if inputLoopChanged {
        //        log("loopInsertEval: will set input loop directly in output")
        let newOutputsValues: PortValuesList = [
            currentInput,
            buildIndicesLoop(loop: currentInput)
        ]
        return .init(outputsValues: newOutputsValues,
                     mediaList: existingMediaList)
    } else if shouldEval {
        //        log("loopInsertEval: will insert")

        // If we have a new loop input, then we use that;
        // else we use current output
        var loop: PortValues = inputLoopChanged
            ? (inputsValues.first ?? defaultFirstInputs)
            : outputsValues.first ?? [.number(.zero)]

        // Loops can be inserted into `loop`, but flat.
        let valueToInsert: PortValues = inputsValues[safe: 1] ?? [.color(.purple)]

        /*
         Notes:
         1. negative indices must be turned to loop-insert-friendly ones
         2. apparently, if index input is loop, we default to index 0
         */
        let modificationIndex = isInsert ? 2 : 1
        let indexToModify: Int = [inputsValues[safe: modificationIndex]?.first?.getNumber?
            .toInt ?? .zero]
            .asLoopInsertFriendlyIndices(loop.count).first ?? .zero

        // TODO: mod the index-to-insert-at by; but an index > loop
        valueToInsert.enumerated().forEach { (index: Int, value: PortValue) in
            switch node.kind.getPatch {
            case .loopInsert:
                let media = newMediaListToInsert[safe: index] ?? nil
                
                if (indexToModify < 0) || (indexToModify > (loop.count - 1)) {
                    // .insert doesn't support negative numbers
                    //                log("loopInsertEval: will add value to back: \(value)")
                    loop.append(value)
                    
                    // Add media and a new ephemeral observer
                    if existingMediaList != nil {
                        existingMediaList?.append(media)
                    }

                } else {
                    // replaces the value?
                    //                log("loopInsertEval: will add value: \(value) at \(indexToInsertAt)")
                    
                    if loop.count > indexToModify {
                        loop.insert(value, at: indexToModify)
                    }
                    
                    // Add media and a new ephemeral observer
                    if (existingMediaList?.count ?? -1) > indexToModify {
                        existingMediaList?.insert(media, at: index)
                    }
                }
                
            case .loopRemove:
                // Loop count can't go below 1
                if loop.count == 1 {
                    loop = [node.userVisibleType?.defaultPortValue ?? LoopRemoveNode._defaultUserVisibleType.defaultPortValue]
                } else {
                    if loop.count > indexToModify {
                        loop.remove(at: indexToModify)
                    }
                    
                    if (existingMediaList?.count ?? -1) > indexToModify {
                        existingMediaList?.remove(at: indexToModify)
                    }
                }
                
                
            default:
                fatalErrorIfDebug()
            }
        }
        let newOutputsValues: PortValuesList = [loop, buildIndicesLoop(loop: loop)]

        return .init(outputsValues: newOutputsValues,
                     mediaList: existingMediaList)
    } else {
        //        log("loopInsertEval: will not insert")
        let _values = outputsValues.first ?? [.number(.zero)]
        
        let existingOutputMedia = computedStates.map(\.computedMedia)
        
        let newOutputsValues: PortValuesList = [
            _values,
            buildIndicesLoop(loop: _values)
        ]
        return .init(outputsValues: newOutputsValues,
                     mediaList: existingOutputMedia)
    }
}

//
//  LoopedEval.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation
import StitchSchemaKit

typealias OpWithIndex<T> = (PortValues, Int) -> T
typealias NodeEphemeralObservableOp<OpResult, EphemeralObserver> = (PortValues, EphemeralObserver, Int) -> OpResult where OpResult: NodeEvalOpResultable, EphemeralObserver: NodeEphemeralObservable

typealias NodeEphemeralObservableListOp<OpResult, EphemeralObserver> = (PortValuesList, EphemeralObserver) -> OpResult where OpResult: NodeEvalOpResultable, EphemeralObserver: NodeEphemeralObservable

typealias NodeEphemeralInteractiveOp<T, EphemeralObserver> = (PortValues, EphemeralObserver, InteractiveLayer, Int) -> T where EphemeralObserver: NodeEphemeralObservable

typealias NodeInteractiveOp<T> = (PortValues, InteractiveLayer, Int) -> T

typealias NodeLayerViewModelInteractiveOp<T> = (LayerViewModel, InteractiveLayer, Int) -> T

/// Allows for generic results while ensure there's some way to get default output values.
protocol NodeEvalOpResultable {
    var values: PortValues { get }
    
    init(from values: PortValues)
    
    @MainActor
    static func createEvalResult(from results: [Self],
                                 node: NodeViewModel) -> EvalResult
}

/// Default node eval op scenario. Can be leveraged by animation nodes to use run-again functionality.
struct NodeEvalOpResult {
    let values: PortValues
    var willRunAgain = false
}

extension NodeEvalOpResult: NodeEvalOpResultable {
    init(from values: PortValues) {
        self.values = values
    }

    static func createEvalResult(from results: [NodeEvalOpResult],
                                 node: NodeViewModel) -> EvalResult {
        let _willRunAgain = results.contains { $0.willRunAgain }
        return .init(outputsValues: results.map(\.values),
                     runAgain: _willRunAgain)
    }
}

extension NodeViewModel {
    /// Looped eval helper used for interaction patch nodes.
    @MainActor
    func loopedEval<EvalOpResult: NodeEvalOpResultable, EphemeralObserver>(_ ephemeralObserverType: EphemeralObserver.Type,
                                                                           graphState: GraphState,
                                                                           evalOp: @escaping NodeEphemeralInteractiveOp<EvalOpResult, EphemeralObserver>) -> EvalResult {
        let results = self.getLoopedEvalResults(ephemeralObserverType,
                                                graphState: graphState,
                                                evalOp: evalOp)
        
        return EvalOpResult.createEvalResult(from: results,
                                             node: self)
    }
    
    /// Looped eval helper used for interaction patch nodes.
    @MainActor
    func getLoopedEvalResults<EvalOpResult: NodeEvalOpResultable,
                              EphemeralObserver>(_ ephemeralObserverType: EphemeralObserver.Type,
                                                 graphState: GraphState,
                                                 evalOp: @escaping NodeEphemeralInteractiveOp<EvalOpResult, EphemeralObserver>) -> [EvalOpResult] {
        let inputsValues = self.inputs
        let loopCount = getLongestLoopLength(inputsValues)

        guard let interactionLayerId = inputs.first?.first?.getInteractionId,
              let layerNode = graphState.getNode(interactionLayerId.id)?.layerNode else {
//            log("loopedEval: could not retrieve interactive layer id and layer node")
            return [0..<loopCount].map { _ in
                return .init(from: self.defaultOutputs)
            }
        }
        
        let lengthenedPreviewLayers = adjustArrayLength(loop: layerNode.previewLayerViewModels,
                                                        length: max(loopCount, layerNode.previewLayerViewModels.count))
        
        return self.getLoopedEvalResults(ephemeralObserverType,
                               minLoopCount: layerNode.previewLayerViewModels.count) { values, ephemeralObserver, loopIndex in
            guard let interactiveLayer = lengthenedPreviewLayers[safe: loopIndex]?.interactiveLayer else {
                log("loopedEval: could not find interactive layer for loopIndex \(loopIndex) in lengthenedPreviewLayers \(lengthenedPreviewLayers)")
                return .init(from: self.defaultOutputs)
            }
            return evalOp(values, ephemeralObserver, interactiveLayer, loopIndex)
        }
    }
    
    @MainActor
    func loopedEval<EvalOpResult: NodeEvalOpResultable>(graphState: GraphState,
                                                    // The layer node whose layer view models we will look at;
                                                    // can be assigned-layer (interaction patch node) or layer itself (e.g. group layer scrolling)
                                                    layerNodeId: NodeId,
                                                                  evalOp: @escaping NodeLayerViewModelInteractiveOp<EvalOpResult>) -> EvalResult {
        let results = self.getLoopedEvalResults(graphState: graphState,
                                                layerNodeId: layerNodeId,
                                                evalOp: evalOp)
        
        return EvalOpResult.createEvalResult(from: results,
                                             node: self)
    }
    
    @MainActor
    func getLoopedEvalResults<EvalOpResult: NodeEvalOpResultable>(graphState: GraphState,
                                                    // The layer node whose layer view models we will look at;
                                                    // can be assigned-layer (interaction patch node) or layer itself (e.g. group layer scrolling)
                                                    layerNodeId: NodeId,
                                                    evalOp: @escaping NodeLayerViewModelInteractiveOp<EvalOpResult>) -> [EvalOpResult] {
        let inputsValues = self.inputs
        let loopCount = getLongestLoopLength(inputsValues)

        guard let layerNode = graphState.getNode(layerNodeId)?.layerNode else {
            return [0..<loopCount].map { _ in
                return .init(from: self.defaultOutputs)
            }
        }
        
        let lengthenedPreviewLayers = adjustArrayLength(loop: layerNode.previewLayerViewModels,
                                                        length: max(loopCount, layerNode.previewLayerViewModels.count))
        
        return self.getLoopedEvalResults(minLoopCount: layerNode.previewLayerViewModels.count) { values, loopIndex in
            guard let layerViewModel = lengthenedPreviewLayers[safe: loopIndex] else {
                return .init(from: self.defaultOutputs)
            }
            return evalOp(layerViewModel, layerViewModel.interactiveLayer, loopIndex)
        }
    }
    
    @MainActor
    func loopedEval<EvalOpResult: NodeEvalOpResultable,
                              EphemeralObserver>(_ ephemeralObserverType: EphemeralObserver.Type,
                                                 inputsValuesList: PortValuesList? = nil,
                                                 minLoopCount: Int = 0,
                                                 evalOp: @escaping NodeEphemeralObservableOp<EvalOpResult, EphemeralObserver>) -> EvalResult {
        let results = self.getLoopedEvalResults(ephemeralObserverType,
                                                inputsValuesList: inputsValuesList,
                                                minLoopCount: minLoopCount,
                                                evalOp: evalOp)
        
        return EvalOpResult.createEvalResult(from: results,
                                             node: self)
    }
    
    @MainActor
    func getLoopedEvalResults<EvalOpResult: NodeEvalOpResultable,
                              EphemeralObserver>(_ ephemeralObserverType: EphemeralObserver.Type,
                                                 inputsValuesList: PortValuesList? = nil,
                                                 minLoopCount: Int = 0,
                                                 evalOp: @escaping NodeEphemeralObservableOp<EvalOpResult, EphemeralObserver>) -> [EvalOpResult] {
        let inputsValues = inputsValuesList ?? self.inputs
        let longestLoopLength = max(getLongestLoopLength(inputsValues), minLoopCount)
        
        let castedEphemeralObservers = self.createEphemeralObserverLoop(ephemeralObserverType,
                                                                        count: longestLoopLength)
        
        assertInDebug(longestLoopLength == castedEphemeralObservers.count)
        
        return self.getLoopedEvalResults(inputsValues: inputsValues,
                                         minLoopCount: minLoopCount) { values, loopIndex in
            let ephemeralObserver = castedEphemeralObservers[loopIndex]
            return evalOp(values, ephemeralObserver, loopIndex)
        }
    }
    
    @MainActor func createEphemeralObserverLoop<EphemeralObserver>(_ type: EphemeralObserver.Type,
                                                                   count: Int) -> [EphemeralObserver] where EphemeralObserver: NodeEphemeralObservable {
        guard let ephemeralObservers = self.ephemeralObservers,
              var castedEphemeralObservers = ephemeralObservers as? [EphemeralObserver] else {
            fatalErrorIfDebug()
            return []
        }
        
        // Match ephemeral observers count to longest loop length
        castedEphemeralObservers.adjustArrayLength(to: count) {
            guard let observer = self.createEphemeralObserver() as? EphemeralObserver else {
                fatalErrorIfDebug()
                return nil
            }
            
            return observer
        }
        
        self.ephemeralObservers = castedEphemeralObservers
        return castedEphemeralObservers
    }

    @MainActor
    /// Looped eval for PortValues returning an EvalFlowResult.
    func loopedEval<Result: NodeEvalOpResultable>(evalOp: @escaping OpWithIndex<Result>) -> EvalResult {
        let results = self.getLoopedEvalResults { values, loopIndex in
            evalOp(values, loopIndex)
        }
        
        return Result.createEvalResult(from: results,
                                       node: self)
    }
    
    @MainActor
    /// Looped eval for PortValues returning an EvalFlowResult.
    func loopedEval<Result: NodeEvalOpResultable,
                    Observer: NodeEphemeralObservable>(_ ephemeralObserverType: Observer.Type,
                                                evalOp: @escaping NodeEphemeralObservableOp<Result, Observer>) -> EvalResult {
        let results = self.getLoopedEvalResults(Observer.self) { values, ephemeralObserver, loopIndex in
            evalOp(values, ephemeralObserver, loopIndex)
        }
        
        return Result.createEvalResult(from: results,
                                       node: self)
    }
    
    @MainActor
    func loopedEval<EvalOpResult: NodeEvalOpResultable>(inputsValues: PortValuesList? = nil,
                                                        minLoopCount: Int = 0,
                                                        shouldAddOutputs: Bool = true,
                                                        evalOp: @escaping OpWithIndex<EvalOpResult>) -> EvalResult {
        let results = self.getLoopedEvalResults(inputsValues: inputsValues,
                                                minLoopCount: minLoopCount,
                                                shouldAddOutputs: shouldAddOutputs,
                                                evalOp: evalOp)
        
        return EvalOpResult.createEvalResult(from: results,
                                             node: self)
    }
    
    @MainActor
    func getLoopedEvalResults<EvalOpResult: NodeEvalOpResultable>(inputsValues: PortValuesList? = nil,
                                                                minLoopCount: Int = 0,
                                                                shouldAddOutputs: Bool = true,
                                                                evalOp: @escaping OpWithIndex<EvalOpResult>) -> [EvalOpResult] {
        let inputsValues = inputsValues ?? self.inputs
        let outputsValues = self.outputs
        
        
        let longestLoopLength = max(getLongestLoopLength(inputsValues), minLoopCount)
        let lengthenedInputs = getLengthenedArrays(inputsValues,
                                                   longestLoopLength: longestLoopLength)
        
        // Remaps values by loop index
        let remappedLengthenedInputs = lengthenedInputs.remapValuesByLoop()
        let remappedOutputs = outputsValues.remapValuesByLoop()
        
        let results = remappedLengthenedInputs.enumerated().map { loopIndex, inputValues in
            var callArgs = inputValues
            
            // Note: some evals (e.g. JSON Array) assume we are iterating over only the inputs
            if shouldAddOutputs,
               // Only add outputs if they exist
                let outputs = remappedOutputs[safe: loopIndex] {
                callArgs += outputs
            }

            return evalOp(callArgs, loopIndex)
        }
            
        return results
    }
    
    /// Saves previous values in `ComputedNodeState`.
    @MainActor
    func loopedEvalOutputsPersistence(graphTime: TimeInterval,
                                      callback: @escaping (PortValues, ComputedNodeState) -> PortValue) -> EvalResult {
        self.loopedEval(ComputedNodeState.self) { values, computedState, _ in
            let newValue = callback(values,
                                    computedState)
            computedState.previousValue = newValue
            
            return [newValue]
        }
    }
    
    /// Saves previous values in some `NodeEphemeralOutputPersistence`.
    @MainActor
    func loopedEvalOutputsPersistence<PersistenceObserver, EvalOpResult>(callback: @escaping (PortValues, PersistenceObserver, Int) -> EvalOpResult) -> EvalResult where PersistenceObserver: NodeEphemeralOutputPersistence, EvalOpResult: NodeEvalOpResultable {
        self.loopedEval(PersistenceObserver.self) { values, observerOp, loopIndex in
            let result = callback(values, observerOp, loopIndex)
            observerOp.previousValue = result.values[safe: PersistenceObserver.outputIndexToSave]
            
            return result
        }
    }
}

@MainActor
func loopedEval<EvalOpResult>(inputsValues: PortValuesList,
                              outputsValues: PortValuesList? = nil,
                              evalOp: @escaping OpWithIndex<EvalOpResult>) -> [EvalOpResult] {

    let areOutputsEmpty = (outputsValues?.flatMap { $0 }.isEmpty) ?? true
    var lengthenedOutputs: PortValuesList = [[]]
    
    let longestLoopLength = getLongestLoopLength(inputsValues)

    let lengthenedInputs = getLengthenedArrays(inputsValues,
                                               longestLoopLength: longestLoopLength)
    
    if let outputsValues = outputsValues {
        lengthenedOutputs = getLengthenedArrays(outputsValues,
                                                longestLoopLength: longestLoopLength)
    }

    // Outputs can't extend length if empty
    let allValues = areOutputsEmpty ? lengthenedInputs : lengthenedInputs + lengthenedOutputs

    let results = (0..<longestLoopLength).map { (index: Int) in
        let callArgs: PortValues = allValues.map { $0[index] }
        return evalOp(callArgs, index)
    }

    return results
}

@MainActor
func loopedEval<EvalOpResult>(node: PatchNode,
                              evalOp: @escaping OpWithIndex<EvalOpResult>) -> [EvalOpResult] {
    #if DEBUG
    // Wrong eval helper if node has ephemeral state
    assert(node.kind.graphNode?.createEphemeralObserver() == nil)
    #endif
    
    // MARK: we no longer lengthen outputs due to empty values at initialization, conditional existence needs to be handled at eval
    let longestLoopLength = getLongestLoopLength(node.inputs)
    let lengthenedInputs = getLengthenedArrays(node.inputs,
                                               longestLoopLength: longestLoopLength)

    // Remaps values by loop index
    let remappedLengthenedInputs = lengthenedInputs.remapValuesByLoop()
    let remappedOutputs = node.outputs.remapValuesByLoop()

    let results = remappedLengthenedInputs.enumerated().map { loopIndex, inputValues in
        var callArgs = inputValues

        // Only add outputs if they exist
        if let outputs = remappedOutputs[safe: loopIndex] {
            callArgs += outputs
        }

        return evalOp(callArgs, loopIndex)
    }

    return results
}

//
//  AsyncMediaImpureEvalResult.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/3/23.
//

import Foundation
import StitchSchemaKit

/// Mutates some media object on the main thread, not meant for computationally heavy tasks.
/// i.e. should be used for play/pause on a video file or transforming a 3D model's matrix.
typealias MediaObjectMutator = @MainActor @Sendable (StitchMediaObject) -> Void

enum AsyncMediaOutputs {
    case byIndex(PortValues)
    case all(PortValuesList)
}

extension AsyncMediaOutputs: NodeEvalOpResult {
    init(from values: PortValues) {
        self = .byIndex(values)
    }
}

extension AsyncMediaOutputs {
    var getAll: PortValuesList? {
        switch self {
        case .all(let x): return x
        default: return nil
        }
    }

    var getByIndex: PortValues? {
        switch self {
        case .byIndex(let x): return x
        default: return nil
        }
    }

    var count: Int {
        switch self {
        case .all(let x): return x.count
        case .byIndex(let x): return x.count
        }
    }
}

extension PortValuesList {
    func toImpureEvalResult() -> ImpureEvalResult {
        let outputs = self.remapOutputs()
        return .init(outputsValues: outputs)
    }
}

extension Array where Element == ImpureEvalOpResult {
    func toImpureEvalResult() -> ImpureEvalResult {
        let outputValues = self.map { $0.outputs }
            .remapOutputs()
        
        return .init(outputsValues: outputValues,
                     runAgain: self.contains(where: { $0.willRunAgain }))
    }
}

extension Array where Element == AsyncMediaOutputs {
    func toImpureEvalResult() -> ImpureEvalResult {
        let results = self
        guard let firstOpResult = results.first else {
            log("AsyncMediaImpureEvalResults: toImpureEvalResult: empty")
            fatalErrorIfDebug()
            return .init(outputsValues: [])
        }
        
        // We use the first op-result as heuristic for whether the media node's eval was index-to-index (i.e. one-to-one, e.g. grayscale node)
        // or index-to-loop (i.e. one-to-many, e.g. object detection node)
        switch firstOpResult {

        // New "one input index -> many outputs"
        case .all(let portValuesList):
            return ImpureEvalResult(outputsValues: portValuesList)

        // Original "one input index -> one output index"
        case .byIndex:
            let allOutputs: PortValuesList = results.compactMap { $0.getByIndex }
            let newOutputs = allOutputs.remapOutputs()

            return ImpureEvalResult(outputsValues: newOutputs)
        }
    }
}

extension PortValuesList? {
    func toImpureEvalResult(defaultOutputs: PortValuesList) -> ImpureEvalResult {
        guard let results = self else {
            fatalErrorIfDebug()
            return .init(outputsValues: defaultOutputs)
        }
        
        return results.toImpureEvalResult()
    }
}

extension PortValuesList {
    func createPureEvalResult() -> EvalResult {
        // Values need to be re-mapped by port index since self
        // is an array of results for each loop index.
        let outputs = self.remapOutputs()
        return .init(outputsValues: outputs)
    }
}

//
//  LoopToArrayNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit
import SwiftyJSON

@MainActor
func loopToArrayNode(id: NodeId,
                     position: CGPoint = .zero,
                     zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Loop", [.number(0)]) // 0
    )

    let json = JSON(rawValue: [0])?.toStitchJSON ?? .emptyJSONArray

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.json(json)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .loopToArray,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

// LoopToArray's output, when measured via LoopCount, always seems to be 1.
// So we're always returning a single array, and never a loop of arrays.
@MainActor
func loopToArrayEval(node: NodeViewModel) -> EvalResult {
    guard let firstRow = node.getInputRowObserver(0) else {
        fatalErrorIfDebug()
        return .init(outputsValues: [[.json(.emptyJSONArray)]])
    }
    
    let jsonArrayFromValues = JSON.jsonLoopToArrayFromValues(firstRow.allLoopedValues)
    
    let outputsValues: PortValuesList = [
        [
            .init(jsonArrayFromValues ?? JSON.emptyArray)
        ]
    ]
    
    return .init(outputsValues: outputsValues)
}

extension JSON {
    @MainActor
    static func jsonLoopToArrayFromValues(_ values: PortValues) -> JSON? {
        let jsonValues = values.map { $0.createJSONFormat() }
        
        if let encoded = try? JSONEncoder().encode(jsonValues),
           let json = try? JSON(data: encoded) {
            
#if DEV_DEBUG
            if !json.array.isDefined {
                fatalError()
            }
#endif
            
            return json
        }
        return nil
    }
}

//
//  LoopToArrayNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit
import SwiftyJSON

struct LoopToArrayPatchNode: PatchNodeDefinition {
    static let patch = Patch.loopToArray
    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        let effectiveType = type ?? .number
        let defaultValue = effectiveType.defaultPortValue

        return .init(
            inputs: [
                .init(
                    defaultValues: [defaultValue],
                    label: "Loop"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .json
                )
            ]
        )
    }
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

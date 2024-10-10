//
//  SetValueForKeyNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/13/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

@MainActor
func setValueForKeyNode(id: NodeId,
                        key: String = "",
                        startingJson: StitchJSON = emptyStitchJSONObject,
                        position: CGSize = .zero,
                        zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Object", [.json(startingJson)]), // 0
        ("Key", [.string(.init(key))]), // 0
        ("Value", [numberDefaultFalse]) // 0
    )

    let outputJson: StitchJSON = emptyStitchJSONObject

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        // it's called index, but it's actually the loop that's coming out
        values:
            ("Object", [.json(outputJson)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .setValueForKey,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func setValueForKeyEval(node: NodeViewModel) -> EvalResult {
    node.loopedEval { values, _ in
        let jsonObject = values.first?.getJSON ?? .emptyJSONObject
        let key = values[safe: 1]?.getString?.string ?? ""
        
        guard let value = values[safe: 2] else {
            fatalErrorIfDebug()
            return [.json(.emptyJSONObject)]
        }
        
        //        #if DEV_DEBUG
        //        log("setValueForKeyEval: setValueForKey(jsonObject, key, value): \(setValueForKey(jsonObject, key, value))")
        //        #endif
        
        // TODO: Should not work if json is array?
        let j = jsonObject.setValueForKey(key, value)
        return [.json(j.toStitchJSON)]
    }
    .createPureEvalResult()
}

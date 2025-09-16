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

struct SetValueForKeyPatchNode: PatchNodeDefinition {
    static let patch = Patch.setValueForKey
    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.json(emptyStitchJSONObject)],
                    label: "Object",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.string(.init(""))],
                    label: "Key",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [numberDefaultFalse],
                    label: "Value"
                )
            ],
            outputs: [
                .init(
                    label: "Object",
                    type: .json
                )
            ]
        )
    }
}


@MainActor
func setValueForKeyEval(node: NodeViewModel) -> EvalResult {
    node.loopedEval { (values, _) -> PortValues in
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
}

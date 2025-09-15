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
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
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

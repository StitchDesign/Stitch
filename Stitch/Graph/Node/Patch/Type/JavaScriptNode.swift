//
//  JavaScriptNode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/24/25.
//

import SwiftUI
import StitchSchemaKit

struct JavaScriptNode: PatchNodeDefinition {
    static let patch = Patch.javascript

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            // must contain one row to support add rows
            inputs: [.init(defaultType: .string, canDirectlyCopyUpstreamValues: true)],
            outputs: []
        )
    }
    
    @MainActor
    static func evaluate(node: NodeViewModel) -> EvalResult? {
        log("javascript ran")
        return .init(outputsValues: [[.number(.zero)]])
    }
}

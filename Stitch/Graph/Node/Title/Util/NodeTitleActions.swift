//
//  NodeTitleActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/27/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct NodeTitleEdited: GraphEventWithResponse {
    let id: NodeId
    let edit: String
    let isCommitting: Bool

    func handle(state: GraphState) -> GraphResponse {
        guard let node = state.getNodeViewModel(id) else {
            log("NodeTitleEdited: could not retrieve node \(id)...")
            return .noChange
        }
        node.title = edit
        
        return .init(willPersist: isCommitting)
    }
}

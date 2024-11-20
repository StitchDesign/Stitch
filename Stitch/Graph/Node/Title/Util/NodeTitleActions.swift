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
    let titleEditType: StitchTitleEdit
    let edit: String
    let isCommitting: Bool

    func handle(state: GraphState) -> GraphResponse {
        switch titleEditType {
        case .canvas(let id):
            guard let node = state.getNode(id.associatedNodeId) else {
                log("NodeTitleEdited: could not retrieve node \(id)...")
                return .noChange
            }
            node.title = edit
            
            // Check for component
            if let componentNode = node.componentNode {
                componentNode.graph.name = edit

                // Always save changes to disk (hack for when view disappears before finishing)
                componentNode.graph.encodeProjectInBackground()
            }
            
            // Resize node
            node.patchCanvasItem?.resetViewSizingCache()

        case .layerInspector(let id):
            guard let node = state.getNodeViewModel(id) else {
                return .noChange
            }
            
            node.title = edit
        }
        
        return .init(willPersist: isCommitting)
    }
}


extension CanvasItemId {
    var isNode: Bool {
        switch self {
        case .node:
            return true
        default:
            return false
        }
    }
    
    // Is this a canvas item for a layer input or output?
    var isForLayer: Bool {
        switch self {
        case .layerInput, .layerOutput:
            return true
        default:
            return false
        }
    }
    
    // Every canvas item belongs to some node, whether patch or layer.
    var associatedNodeId: NodeId {
        switch self {
        case .node(let x):
            return x
        case .layerInput(let x):
            return x.node
        case .layerOutput(let x):
            return x.node
        }
    }
}

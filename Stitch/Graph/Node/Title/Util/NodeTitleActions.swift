//
//  NodeTitleActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/27/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension NodeViewModel {
    @MainActor
    func nodeTitleEdited(titleEditType: StitchTitleEdit,
                         edit: String,
                         isCommitting: Bool,
                         graph: GraphState) {
        switch titleEditType {
        case .canvas:
            self.title = edit
            
            // Check for component
            if let componentNode = self.componentNode {
                componentNode.graph.name = edit
                
                // Always save changes to disk (hack for when view disappears before finishing)
                componentNode.graph.encodeProjectInBackground()
            }
            
            // Resize node
            self.nonLayerCanvasItem?.resetViewSizingCache()
            
        case .layerInspector:
            self.title = edit
        }
        
        if isCommitting {
            graph.encodeProjectInBackground()
        }
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

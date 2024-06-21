//
//  NodeViewModelType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/27/23.
//

import SwiftUI
import StitchSchemaKit

// Is this node a LayerNode, PatchNode or GroupNode?
// Like `NodeKind` but contains node-kind specific data
// fka `NodeViewModelType`
enum NodeViewModelKind {
    case patch(PatchNodeViewModel)
    case group(GroupNodeViewModel)
    case layer(LayerNodeViewModel)
}

// Becomes very important, since inputs/outputs, position etc. are now all held here.
extension NodeViewModelKind {
    @MainActor
    init(from schema: NodeEntity,
         nodeDelegate: NodeDelegate?) {
        if let patchNode = schema.patchNodeEntity {
            let viewModel = PatchNodeViewModel(from: patchNode)
            viewModel.nodeData = NodeDataViewModel(
                id: schema.id,
                // pass the node delegate here?
                canvasUIData: CanvasItemViewModel.fromSchemaWithoutDelegate(schema),
                // populate these inputs etc.?
                inputs: [],
                outputs: [])
            self = .patch(viewModel)
        } else if let layerNode = schema.layerNodeEntity {
            let viewModel = LayerNodeViewModel(from: layerNode,
                                               nodeDelegate: nodeDelegate)
            self = .layer(viewModel)
        } else {
            let viewModel = GroupNodeViewModel.fromSchemaWithoutDelegate(from: schema)
            viewModel.nodeData = NodeDataViewModel(
                id: schema.id,
                canvasUIData: CanvasItemViewModel.fromSchemaWithoutDelegate(schema),
                // For a group node, inputs and outputs are constructed later
                inputs: [],
                outputs: [])
            self = .group(viewModel)
        }
    }

    // Not used? Also, wasn't covering the LayerNode case?
    @MainActor
    func update(from schema: NodeEntity) {
        if let patchNode = schema.patchNodeEntity {
            let viewModel = PatchNodeViewModel(from: patchNode)
            viewModel.update(from: patchNode)
        } else {
            #if DEBUG
            fatalError()
            #endif
        }
    }
}

extension NodeViewModelKind {
    var patchNode: PatchNodeViewModel? {
        switch self {
        case .patch(let patchNode):
            return patchNode
        default:
            return nil
        }
    }

    var layerNode: LayerNodeViewModel? {
        switch self {
        case .layer(let layerNode):
            return layerNode
        default:
            return nil
        }
    }

    var kind: NodeKind {
        switch self {
        case .patch(let patchNode):
            return .patch(patchNode.patch)
        case .layer(let layerNode):
            return .layer(layerNode.layer)
        case .group:
            return .group
        }
    }
}

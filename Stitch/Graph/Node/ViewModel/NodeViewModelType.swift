//
//  NodeViewModelType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/27/23.
//

import SwiftUI
import StitchSchemaKit

enum NodeViewModelType {
    case patch(PatchNodeViewModel)
    case layer(LayerNodeViewModel)
    case group
}

extension NodeViewModelType {
    @MainActor
    init(from schema: NodeEntity,
         nodeDelegate: NodeDelegate?) {
        if let patchNode = schema.patchNodeEntity {
            let viewModel = PatchNodeViewModel(from: patchNode)
            self = .patch(viewModel)
        } else if let layerNode = schema.layerNodeEntity {
            let viewModel = LayerNodeViewModel(from: layerNode, 
                                               nodeDelegate: nodeDelegate)
            self = .layer(viewModel)
        } else {
            self = .group
        }
    }

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

extension NodeViewModelType {
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

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
    case group(CanvasNodeViewModel)
}

extension NodeViewModelType {
    @MainActor
    init(from nodeType: NodeTypeEntity,
         nodeDelegate: NodeDelegate?) {
        switch nodeType {
        case .patch(let patchNode):
            let viewModel = PatchNodeViewModel(from: patchNode)
            self = .patch(viewModel)
        case .layer(let layerNode):
            let viewModel = LayerNodeViewModel(from: layerNode,
                                               nodeDelegate: nodeDelegate)
            self = .layer(viewModel)
        case .group(let canvasNode):
            self = .group()
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

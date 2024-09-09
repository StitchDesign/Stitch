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
    case group(CanvasItemViewModel)
    case component(StitchComponentViewModel)
}

final class StitchComponentViewModel {
    var componentId: UUID
    let canvas: CanvasItemViewModel
    
    init(componentId: UUID, canvas: CanvasItemViewModel) {
        self.componentId = componentId
        self.canvas = canvas
    }
}

extension NodeViewModelType {
    @MainActor
    init(from nodeType: NodeTypeEntity,
         nodeId: NodeId) {
        switch nodeType {
        case .patch(let patchNode):
            let viewModel = PatchNodeViewModel(from: patchNode)
            self = .patch(viewModel)
        case .layer(let layerNode):
            let viewModel = LayerNodeViewModel(from: layerNode)
            self = .layer(viewModel)
        case .group(let canvasNode):
            self = .group(.init(from: canvasNode, 
                                id: .node(nodeId),
                                // Initialize as empty since splitter row observers might not have yet been created
                                inputRowObservers: [],
                                outputRowObservers: [],
                                // Irrelevant
                                unpackedPortParentFieldGroupType: nil,
                                unpackedPortIndex: nil))
        case .component(let component):
            let component = StitchComponentViewModel(
                componentId: component.id,
                canvas: .init(from: component.canvasEntity,
                              id: .node(nodeId),
                              // Initialize as empty since splitter row observers might not have yet been created
                              inputRowObservers: [],
                              outputRowObservers: [],
                              unpackedPortParentFieldGroupType: nil,
                              unpackedPortIndex: nil))
            self = .component(component)
        }
    }
    
    @MainActor func initializeDelegate(_ node: NodeDelegate) {
        switch self {
        case .patch(let patchNodeViewModel):
            guard let patchDelegate = node as? PatchNodeViewModelDelegate else {
                fatalErrorIfDebug()
                return
            }
            
            patchNodeViewModel.initializeDelegate(patchDelegate)
        case .layer(let layerNodeViewModel):
            layerNodeViewModel.initializeDelegate(node)
        case .group(let canvasItemViewModel):
            canvasItemViewModel.initializeDelegate(node,
                                                   // Not relevant
                                                   unpackedPortParentFieldGroupType: nil,
                                                   unpackedPortIndex: nil)
        case .component(let componentViewModel):
            componentViewModel.canvas.initializeDelegate(node,
                                                         unpackedPortParentFieldGroupType: nil,
                                                         unpackedPortIndex: nil)
        }
    }

    @MainActor
    func update(from schema: NodeTypeEntity) {
        switch (self, schema) {
        case (.patch(let patchViewModel), .patch(let patchEntity)):
            patchViewModel.update(from: patchEntity)
        case (.layer(let layerViewModel), .layer(let layerEntity)):
            layerViewModel.update(from: layerEntity)
        case (.group(let canvasViewModel), .group(let canvasEntity)):
            canvasViewModel.update(from: canvasEntity)
        case (.component(let componentViewModel), .component(let component)):
            componentViewModel.componentId = component.id
            componentViewModel.canvas.update(from: component.canvasEntity)
        default:
            log("NodeViewModelType.update error: found unequal view model and schema types for some node type.")
            fatalErrorIfDebug()
        }
    }
    
    @MainActor func createSchema() -> NodeTypeEntity {
        switch self {
        case .patch(let patchNodeViewModel):
            return .patch(patchNodeViewModel.createSchema())
        case .layer(let layerNodeViewModel):
            return .layer(layerNodeViewModel.createSchema())
        case .group(let canvasNodeViewModel):
            return .group(canvasNodeViewModel.createSchema())
        case .component(let component):
            return .component(.init(id: component.componentId,
                                    canvasEntity: component.canvas.createSchema()))
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
    
    var groupNode: CanvasItemViewModel? {
        switch self {
        case .group(let canvas):
            return canvas
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
        case .group, .component:
            return .group
        }
    }
}

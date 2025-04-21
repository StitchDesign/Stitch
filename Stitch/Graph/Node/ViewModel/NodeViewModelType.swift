//
//  NodeViewModelType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/27/23.
//

import SwiftUI
import StitchSchemaKit
import StitchEngine

enum NodeViewModelType {
    case patch(PatchNodeViewModel)
    case layer(LayerNodeViewModel)
    case group(CanvasItemViewModel)
    case component(StitchComponentViewModel)
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
                                outputRowObservers: []))
        case .component(let component):
            self = .component(.init(nodeId: nodeId,
                                    componentEntity: component,
                                    
                                    // TODO: thie gets a new reference later
                                    graph: .createEmpty()))
        }
    }
    
    @MainActor
    init(from nodeType: NodeTypeEntity,
         nodeId: NodeId,
         components: [UUID: StitchMasterComponent],
         parentGraphPath: [UUID]) async {
        switch nodeType {
        case .patch, .layer, .group:
            self = .init(from: nodeType,
                         nodeId: nodeId)
        
        case .component:
            // TODO: unwrapping component changes the ID. no idea why.
            guard let componentEntity = nodeType.componentNodeEntity else {
                fatalError()
            }
            
            guard let masterComponent = components.get(componentEntity.componentId) else {
                fatalErrorIfDebug()
                self = .component(.createEmpty())
                return
            }
            
            let component = await StitchComponentViewModel(
                nodeId: nodeId,
                componentEntity: componentEntity,
                encodedComponent: masterComponent.lastEncodedDocument,
                parentGraphPath: parentGraphPath,
                componentEncoder: masterComponent.encoder)
            self = .component(component)
        }
    }
    
    @MainActor
    func initializeDelegate(_ node: NodeViewModel,
                            components: [UUID: StitchMasterComponent],
                            document: StitchDocumentViewModel) {
        let graph = document.graph
        
        let activeIndex = document.activeIndex
        
        switch self {
        case .patch(let patchNodeViewModel):
            patchNodeViewModel.initializeDelegate(node,
                                                  graph: graph,
                                                  activeIndex: activeIndex)
        case .layer(let layerNodeViewModel):
            layerNodeViewModel.initializeDelegate(node,
                                                  graph: graph,
                                                  activeIndex: activeIndex)
        case .group(let canvasItemViewModel):
            canvasItemViewModel.initializeDelegate(node,
                                                   activeIndex: activeIndex,
                                                   // Not relevant
                                                   unpackedPortParentFieldGroupType: nil,
                                                   unpackedPortIndex: nil)
        case .component(let componentViewModel):
            componentViewModel.initializeDelegate(node: node,
                                                  components: components,
                                                  document: document)
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
            // Rest of updates done with initializeDelegate fn
            componentViewModel.componentId = component.componentId
        default:
            log("NodeViewModelType.update error: found unequal view model and schema types for some node type.")
            fatalErrorIfDebug()
        }
    }
    
    @MainActor
    func update(from schema: NodeTypeEntity,
                components: [UUID: StitchMasterComponent],
                activeIndex: ActiveIndex) async {
        switch (self, schema) {
        case (.component(let componentViewModel), .component(let component)):
            await componentViewModel.update(from: component,
                                            components: components,
                                            activeIndex: activeIndex)
        default:
            self.update(from: schema)
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
            return .component(component.createSchema())
        }
    }
    
    @MainActor func onPrototypeRestart(document: StitchDocumentViewModel) {
        switch self {
        case .patch(let patchNode):
            // Flatten interaction nodes' outputs when graph reset
            if patchNode.patch.isInteractionPatchNode {
                patchNode.outputsObservers.flattenOutputs()
            }
            
        case .layer(let layerNode):
            layerNode.onPrototypeRestart(document: document)
            
        case .component(let component):
            component.graph.onPrototypeRestart(document: document)
            
        case .group:
            return
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
    
    var componentNode: StitchComponentViewModel? {
        switch self {
        case .component(let component):
            return component
        default:
            return nil
        }
    }

    @MainActor
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

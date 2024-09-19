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

/// Unique instance of a component
final class StitchComponentViewModel {
    var componentId: UUID
    let canvas: CanvasItemViewModel
    let graph: GraphState
    
    weak var nodeDelegate: NodeDelegate?
    weak var componentDelegate: StitchMasterComponent?
    
    @MainActor init(componentId: UUID,
                    componentEntity: StitchComponent,
                    canvas: CanvasItemViewModel) {
        self.componentId = componentId
        self.graph = .init(from: componentEntity.graph)
        self.canvas = canvas
    }
}

// TODO: move
extension StitchComponentViewModel {
    @MainActor func initializeDelegate(node: NodeDelegate,
                                       components: [UUID: StitchMasterComponent],
                                       document: StitchDocumentViewModel) {
        self.nodeDelegate = node
        
        guard let masterComponent = components.get(self.id) else {
            fatalErrorIfDebug()
            return
        }
        
        self.componentDelegate = masterComponent
        self.canvas.initializeDelegate(node,
                                       unpackedPortParentFieldGroupType: nil,
                                       unpackedPortIndex: nil)
        self.graph.initializeDelegate(document: document,
                                      documentEncoderDelegate: masterComponent.documentEncoder)
    }
    
    @MainActor func createSchema() -> ComponentEntity {
        let inputs = self.getAllInputsObservers()
            .map { $0.createSchema().portData }
        
        return .init(componentId: self.componentId,
                     inputs: inputs,
                     canvasEntity: self.canvas.createSchema())
    }
    
    @MainActor func update(from schema: ComponentEntity,
                           components: [UUID : StitchMasterComponent]) {
        self.componentId = schema.componentId
        self.canvas.update(from: schema.canvasEntity)
        
        // TODO: zip schema inputs with computed input row observers
        fatalError()
        
        guard let masterComponent = components.get(self.id) else {
            fatalErrorIfDebug()
            return
        }
        self.graph.update(from: masterComponent.draftedComponent.graph)
    }
}

extension StitchComponentViewModel: NodeCalculatable {
    typealias InputRow = InputNodeRowObserver
    typealias OutputRow = OutputNodeRowObserver
    
    var id: NodeId {
        get {
            self.nodeDelegate?.id ?? .init()
        }
        set(newValue) {
            // This used?
            fatalErrorIfDebug()
//            self.nodeDelegate?.id = newValue
        }
    }
    
    var isGroupNode: Bool {
        // TODO: is this right
        true
    }
    
    var requiresOutputValuesChange: Bool {
        false
    }
    
    @MainActor func inputsWillUpdate(values: PortValuesList) {
        fatalError()
    }
    
    @MainActor func evaluate() -> EvalResult? {
        fatalError()
    }
    
    @MainActor func outputsUpdated(evalResult: EvalResult) {
        fatalError()
    }
    
    @MainActor func getAllInputsObservers() -> [InputNodeRowObserver] {
        fatalError()
    }
    
    @MainActor func getAllOutputsObservers() -> [OutputNodeRowObserver] {
        fatalError()
    }
    
    @MainActor func getInputRowObserver(for id: NodeIOPortType) -> InputNodeRowObserver? {
        fatalError()
    }
    
    @MainActor var inputsValuesList: PortValuesList {
        self.getAllInputsObservers().map { $0.allLoopedValues }
    }
}

extension NodeViewModelType {
    @MainActor
    init(from nodeType: NodeTypeEntity,
         nodeId: NodeId,
         components: [UUID: StitchMasterComponent]) {
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
            let componentCanvas = CanvasItemViewModel(from: component.canvasEntity,
                                                      id: .node(nodeId),
                                                      // Initialize as empty since splitter row observers might not have yet been created
                                                      inputRowObservers: [],
                                                      outputRowObservers: [],
                                                      unpackedPortParentFieldGroupType: nil,
                                                      unpackedPortIndex: nil)
            
            guard let masterComponent = components.get(component.componentId) else {
                fatalErrorIfDebug()
                self = .component(.init(componentId: component.componentId,
                                        componentEntity: .init(graph: .init(id: .init(),
                                                                            name: "",
                                                                            nodes: [],
                                                                            orderedSidebarLayers: [],
                                                                            commentBoxes: [],
                                                                            draftedComponents: [])),
                                        canvas: componentCanvas))
                return
            }
            
            let component = StitchComponentViewModel(
                componentId: component.componentId,
                componentEntity: masterComponent.draftedComponent,
                canvas: componentCanvas)
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
    func update(from schema: NodeTypeEntity,
                components: [UUID: StitchMasterComponent]) {
        switch (self, schema) {
        case (.patch(let patchViewModel), .patch(let patchEntity)):
            patchViewModel.update(from: patchEntity)
        case (.layer(let layerViewModel), .layer(let layerEntity)):
            layerViewModel.update(from: layerEntity)
        case (.group(let canvasViewModel), .group(let canvasEntity)):
            canvasViewModel.update(from: canvasEntity)
        case (.component(let componentViewModel), .component(let component)):
            componentViewModel.update(from: component,
                                      components: components)
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
            return .component(component.createSchema())
        }
    }
    
    @MainActor func onPrototypeRestart() {
        switch self {
        case .patch(let patchNode):
            // Flatten interaction nodes' outputs when graph reset
            if patchNode.patch.isInteractionPatchNode {
                patchNode.outputsObservers.flattenOutputs()
            }
            
        case .layer(let layerNode):
            layerNode.previewLayerViewModels.forEach {
                // Rest interaction state values
                $0.interactiveLayer.onPrototypeRestart()
            }
            
        case .component(let component):
            component.graph.onPrototypeRestart()
            
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

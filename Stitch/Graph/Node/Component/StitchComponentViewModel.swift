//
//  StitchComponentViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/4/24.
//

import SwiftUI
import StitchSchemaKit
import StitchEngine

/// Unique instance of a component
final class StitchComponentViewModel {
    var componentId: UUID
    let canvas: CanvasItemViewModel
    let graph: GraphState
    
    weak var nodeDelegate: NodeDelegate?
    weak var componentDelegate: StitchMasterComponent?
    
    init(componentId: UUID,
         canvas: CanvasItemViewModel,
         graph: GraphState,
         nodeDelegate: NodeDelegate? = nil,
         componentDelegate: StitchMasterComponent? = nil) {
        self.componentId = componentId
        self.canvas = canvas
        self.graph = graph
        self.nodeDelegate = nodeDelegate
        self.componentDelegate = componentDelegate
    }
    
    convenience init(componentId: UUID,
                     componentEntity: StitchComponent,
                     canvas: CanvasItemViewModel,
                     parentGraphPath: [UUID],
                     componentEncoder: ComponentEncoder) async {
        let graph = await GraphState(from: componentEntity.graph,
                                     saveLocation: parentGraphPath + [componentId],
                                     encoder: componentEncoder)
        self.init(componentId: componentId,
                  canvas: canvas,
                  graph: graph)
    }
}

extension StitchComponentViewModel {
    static func createEmpty() -> Self {
        .init(componentId: .init(),
              canvas: .init(from: .init(position: .zero,
                                        zIndex: .zero,
                                        parentGroupNodeId: nil),
                            id: .node(.init()),
                            inputRowObservers: [],
                            outputRowObservers: [],
                            unpackedPortParentFieldGroupType: nil,
                            unpackedPortIndex: nil),
              graph: .init())
    }
    
    @MainActor
    func initializeDelegate(node: NodeDelegate,
                            components: [UUID: StitchMasterComponent],
                            document: StitchDocumentViewModel) {
        self.nodeDelegate = node
        
        guard let masterComponent = components.get(self.componentId) else {
            fatalErrorIfDebug()
            return
        }
        
        self.componentDelegate = masterComponent
        self.canvas.initializeDelegate(node,
                                       unpackedPortParentFieldGroupType: nil,
                                       unpackedPortIndex: nil)
        self.graph.initializeDelegate(document: document,
                                      documentEncoderDelegate: masterComponent.draftedDocumentEncoder)
    }
    
    @MainActor func createSchema() -> ComponentEntity {
        let inputs = self.getAllInputsObservers()
            .map { $0.createSchema().portData }
        
        return .init(componentId: self.componentId,
                     inputs: inputs,
                     canvasEntity: self.canvas.createSchema())
    }
    
    @MainActor func update(from schema: ComponentEntity,
                           components: [UUID : StitchMasterComponent]) async {
        self.componentId = schema.componentId
        self.canvas.update(from: schema.canvasEntity)
        
        // TODO: zip schema inputs with computed input row observers
        
        guard let masterComponent = components.get(self.componentId) else {
            fatalErrorIfDebug()
            return
        }
        
        await self.graph.update(from: masterComponent.draftedComponent.graph)
    }
}

extension StitchComponentViewModel: NodeCalculatable {
    typealias InputRow = InputNodeRowObserver
    typealias OutputRow = OutputNodeRowObserver
    
    var id: NodeId {
        get {
            guard let node = self.nodeDelegate else {
                fatalErrorIfDebug()
                return .init()
            }
            
            return node.id
        }
        set(newValue) {
            // This used?
            fatalErrorIfDebug()
//            self.nodeDelegate?.id = newValue
        }
    }
    
    var isGroupNode: Bool {
        false
    }
    
    var requiresOutputValuesChange: Bool {
        false
    }
    
    @MainActor func inputsWillUpdate(values: PortValuesList) {
        fatalError()
    }
    
    @MainActor func evaluate() -> EvalResult? {
        self.graph.calculate(from: self.graph.allNodesToCalculate)
        
        // TODO: fix for splitters
        return nil
    }
    
    @MainActor func outputsUpdated(evalResult: EvalResult) {
        fatalError()
    }
    
    @MainActor func getAllInputsObservers() -> [InputNodeRowObserver] {
        []
    }
    
    @MainActor func getAllOutputsObservers() -> [OutputNodeRowObserver] {
        []
    }
    
    @MainActor func getInputRowObserver(for id: NodeIOPortType) -> InputNodeRowObserver? {
        fatalError()
    }
    
    @MainActor var inputsValuesList: PortValuesList {
        self.getAllInputsObservers().map { $0.allLoopedValues }
    }
}

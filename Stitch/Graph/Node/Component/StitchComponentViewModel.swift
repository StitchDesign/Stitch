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
    
    var inputsObservers: [InputNodeRowObserver] = []
    var outputsObservers: [OutputNodeRowObserver] = []
    
    let canvas: CanvasItemViewModel
    let graph: GraphState
    
    weak var nodeDelegate: NodeDelegate?
    weak var componentDelegate: StitchMasterComponent?
    
    @MainActor
    init(nodeId: UUID,
         componentEntity: ComponentEntity,
         graph: GraphState,
         nodeDelegate: NodeDelegate? = nil,
         componentDelegate: StitchMasterComponent? = nil) {
        self.componentId = componentEntity.componentId
        self.graph = graph
        self.nodeDelegate = nodeDelegate
        self.componentDelegate = componentDelegate
        
        let splitterInputs = Self.getInputSplitters(graph: graph)
        let splitterOutputs = Self.getOutputSplitters(graph: graph)
        
        assertInDebug(componentEntity.inputs.count == splitterInputs.count)
        
        let inputsObservers = zip(componentEntity.inputs, splitterInputs).enumerated().map { index, data in
            let (schemaInput, splitterInput) = data
            
            switch schemaInput {
            case .upstreamConnection(let upstreamCoordinateId):
                return InputNodeRowObserver(values: splitterInput.values,
                                            nodeKind: .group,
                                            userVisibleType: nil,
                                            id: .init(portId: index,
                                                      nodeId: nodeId),
                                            upstreamOutputCoordinate: upstreamCoordinateId)
            case .values(let values):
                return InputNodeRowObserver(values: values,
                                            nodeKind: .group,
                                            userVisibleType: nil,
                                            id: .init(portId: index,
                                                      nodeId: nodeId),
                                            upstreamOutputCoordinate: nil)
            }
        }
        
        let outputsObservers = splitterOutputs.enumerated().map { index, splitterOutput in
            OutputNodeRowObserver(values: splitterOutput.values,
                                  nodeKind: .group,
                                  userVisibleType: nil,
                                  id: .init(portId: index,
                                            nodeId: nodeId))
        }
        
        self.canvas = .init(from: componentEntity.canvasEntity,
                            id: .node(nodeId),
                            inputRowObservers: inputsObservers,
                            outputRowObservers: outputsObservers,
                            unpackedPortParentFieldGroupType: nil,
                            unpackedPortIndex: nil)
        
        self.inputsObservers = inputsObservers
        self.outputsObservers = outputsObservers
    }
    
    @MainActor
    convenience init(nodeId: UUID,
                     componentEntity: ComponentEntity,
                     encodedComponent: StitchComponent,
                     parentGraphPath: [UUID],
                     componentEncoder: ComponentEncoder) async {
        let graph = await GraphState(from: encodedComponent.graph,
                                     saveLocation: parentGraphPath + [componentEntity.componentId],
                                     encoder: componentEncoder)
        self.init(nodeId: nodeId,
                  componentEntity: componentEntity,
                  graph: graph)
    }
}

extension StitchComponentViewModel {
    @MainActor static func createEmpty() -> Self {
        .init(nodeId: .init(),
              componentEntity: ComponentEntity(componentId: .init(),
                                               inputs: [],
                                               canvasEntity: .init(position: .zero,
                                                                   zIndex: .zero,
                                                                   parentGroupNodeId: nil)),
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
                                      documentEncoderDelegate: masterComponent.encoder)
        
        self.inputsObservers.forEach { $0.initializeDelegate(node) }
        self.outputsObservers.forEach { $0.initializeDelegate(node) }
    }
    
    @MainActor func createSchema() -> ComponentEntity {
        let inputs = self.inputsObservers
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
        
        await self.graph.update(from: masterComponent.lastEncodedDocument.graph)
    }
    
    @MainActor
    static func getInputSplitters(graph: GraphState) -> [InputNodeRowObserver] {
        graph.visibleNodesViewModel.getSplitterInputRowObservers(for: nil)
    }
    
    @MainActor
    static func getOutputSplitters(graph: GraphState) -> [OutputNodeRowObserver] {
        graph.visibleNodesViewModel.getSplitterOutputRowObservers(for: nil)
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
        // Update splitters
        let splitterInputs = Self.getInputSplitters(graph: self.graph)
        let splitterOutputs = Self.getOutputSplitters(graph: self.graph)
        
        assertInDebug(splitterInputs.count == self.inputsObservers.count)
        assertInDebug(splitterOutputs.count == self.outputsObservers.count)
        
        // Update graph's inputs before calculating full graph
        zip(splitterInputs, self.inputsObservers).forEach { splitter, input in
            splitter.updateValues(input.allLoopedValues)
        }

        self.graph.calculate(from: self.graph.allNodesToCalculate)
        
        // Update outputs here after graph calculation
        zip(splitterOutputs, self.outputsObservers).forEach { splitter, output in
            splitter.updateValues(output.allLoopedValues)
        }
        
        return .init(outputsValues: self.outputsObservers.map(\.allLoopedValues))
    }
    
    @MainActor func outputsUpdated(evalResult: EvalResult) {
        fatalError()
    }
    
    @MainActor func getInputRowObserver(for id: NodeIOPortType) -> InputNodeRowObserver? {
        guard let portId = id.portId,
              let input = self.inputsObservers[safe: portId] else {
            fatalErrorIfDebug()
            return nil
        }
        
        return input
    }
    
    @MainActor var inputsValuesList: PortValuesList {
        self.inputsObservers.map { $0.allLoopedValues }
    }
}

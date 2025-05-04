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
final class StitchComponentViewModel: Sendable {
    @MainActor var componentId: UUID
    
    @MainActor var inputsObservers: [InputNodeRowObserver] = []
    @MainActor var outputsObservers: [OutputNodeRowObserver] = []
    
    let canvas: CanvasItemViewModel
    
    // One for each loop index
    var graphs: [GraphState]
    
    @MainActor weak var nodeDelegate: NodeViewModel?
    @MainActor weak var componentDelegate: StitchMasterComponent?
    
    @MainActor
    init(nodeId: UUID,
         componentEntity: ComponentEntity,
         graph: GraphState,
         nodeDelegate: NodeViewModel? = nil,
         componentDelegate: StitchMasterComponent? = nil) {
        self.componentId = componentEntity.componentId
        self.graph = graph
        self.nodeDelegate = nodeDelegate
        self.componentDelegate = componentDelegate
        
        let inputsObservers = Self.refreshInputs(schemaInputs: componentEntity.inputs,
                                                 graph: graph,
                                                 nodeId: nodeId,
                                                 existingInputsObservers: [])
        let outputsObservers = Self.refreshOutputs(graph: graph,
                                                   nodeId: nodeId,
                                                   existingOutputsObservers: [])

        self.canvas = .init(from: componentEntity.canvasEntity,
                            id: .node(nodeId),
                            inputRowObservers: inputsObservers,
                            outputRowObservers: outputsObservers)
            
        self.inputsObservers = inputsObservers
        self.outputsObservers = outputsObservers
    }
    
    @MainActor
    func refreshPorts(schemaInputs: [NodeConnectionType]? = nil,
                      activeIndex: ActiveIndex) {
        let schemaInputs = schemaInputs ?? self.createSchema().inputs
        
        self.inputsObservers = self.refreshInputs(schemaInputs: schemaInputs)
        self.outputsObservers = self.refreshOutputs()
        self.canvas.syncRowViewModels(inputRowObservers: inputsObservers,
                                      outputRowObservers: outputsObservers,
                                      activeIndex: activeIndex)
    }
    
    @MainActor
    func refreshInputs(schemaInputs: [NodeConnectionType]) -> [InputNodeRowObserver] {
        Self.refreshInputs(schemaInputs: schemaInputs,
                           graph: self.graph,
                           nodeId: self.id,
                           existingInputsObservers: self.inputsObservers)
    }
    
    @MainActor
    static func refreshInputs(schemaInputs: [NodeConnectionType],
                              graph: GraphState,
                              nodeId: UUID,
                              existingInputsObservers: [InputNodeRowObserver]) -> [InputNodeRowObserver] {
        let splitterInputs = Self.getInputSplitters(graph: graph)
        
        let newInputs = splitterInputs.enumerated().compactMap { index, splitterInput -> InputNodeRowObserver? in
            let schemaInput = schemaInputs[safe: index]
            
            if let existingInput = existingInputsObservers[safe: index] {
                guard let schemaInput = schemaInput else {
                    // Expected schema input here
                    fatalErrorIfDebug()
                    return nil
                }

                let portSchema = NodePortInputEntity(id: .init(portId: index,
                                                               nodeId: nodeId),
                                                     portData: schemaInput)
                existingInput.update(from: portSchema)
                
                return existingInput
            }
            
            switch schemaInput {
            case .upstreamConnection(let upstreamCoordinateId):
                return InputNodeRowObserver(values: splitterInput.values,
                                            id: .init(portId: index,
                                                      nodeId: nodeId),
                                            upstreamOutputCoordinate: upstreamCoordinateId)

            default:
                let values = schemaInput?.values ?? splitterInput.allLoopedValues
                return InputNodeRowObserver(values: values,
                                            id: .init(portId: index,
                                                      nodeId: nodeId),
                                            upstreamOutputCoordinate: nil)
            }
        }
        
        return newInputs
    }
    
    @MainActor
    func refreshOutputs() -> [OutputNodeRowObserver] {
        Self.refreshOutputs(graph: self.graph,
                            nodeId: self.id,
                            existingOutputsObservers: self.outputsObservers)
    }
    
    @MainActor
    static func refreshOutputs(graph: GraphState,
                               nodeId: NodeId,
                               existingOutputsObservers: [OutputNodeRowObserver]) -> [OutputNodeRowObserver] {
        let splitterOutputs = Self.getOutputSplitters(graph: graph)
        let outputsObservers = splitterOutputs.enumerated().map { index, splitterOutput in
            if let existingOutput = existingOutputsObservers[safe: index] {
                existingOutput.updateValuesInOutput(splitterOutput.values, graph: graph)
                return existingOutput
            }
            
            return OutputNodeRowObserver(values: splitterOutput.values,
                                         id: .init(portId: index,
                                                   nodeId: nodeId))
        }
        
        return outputsObservers
    }
    
    @MainActor
    convenience init(nodeId: UUID,
                     componentEntity: ComponentEntity,
                     encodedComponent: StitchComponent,
                     parentGraphPath: [UUID],
                     componentEncoder: ComponentEncoder) async {
        let graph = await GraphState(from: encodedComponent.graph,
                                     // TODO: ComponentEntity or GraphEntity should persist their own localPosition?
                                     localPosition: ABSOLUTE_GRAPH_CENTER,
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
    func initializeDelegate(node: NodeViewModel,
                            components: [UUID: StitchMasterComponent],
                            document: StitchDocumentViewModel) {
        self.nodeDelegate = node
        
        guard let masterComponent = components.get(self.componentId) else {
            fatalErrorIfDebug()
            return
        }
        
        self.componentDelegate = masterComponent
        self.canvas.initializeDelegate(node,
                                       activeIndex: document.activeIndex,
                                       unpackedPortParentFieldGroupType: nil,
                                       unpackedPortIndex: nil)
        self.graphs.forEach {
            $0.initializeDelegate(document: document,
                                    documentEncoderDelegate: masterComponent.encoder)
        }
        
        // Updates inputs and outputs
        // TODO: how does this work if input observers have one graph?
        self.inputsObservers.forEach { $0.initializeDelegate(node, graph: self.graph) }
        self.outputsObservers.forEach { $0.initializeDelegate(node, graph: self.graph) }
        
        // Refresh port data
        self.refreshPorts(activeIndex: document.activeIndex)
    }
    
    @MainActor func createSchema() -> ComponentEntity {
        let inputs = self.inputsObservers
            .map { $0.createSchema().portData }
        
        return .init(componentId: self.componentId,
                     inputs: inputs,
                     canvasEntity: self.canvas.createSchema())
    }
    
    @MainActor func update(from schema: ComponentEntity,
                           components: [UUID : StitchMasterComponent],
                           activeIndex: ActiveIndex) {
        self.componentId = schema.componentId
        
        guard let masterComponent = components.get(self.componentId) else {
            fatalErrorIfDebug()
            return
        }
        
        self.graphs.forEach {
            $0.update(from: masterComponent.lastEncodedDocument.graph)
        }
        
        // Refresh after graph update
        self.canvas.update(from: schema.canvasEntity)
        self.refreshPorts(schemaInputs: schema.inputs,
                          activeIndex: activeIndex)
    }
    
    @MainActor func syncPorts(schemaInputs: [NodeConnectionType]? = nil,
                              activeIndex: ActiveIndex) {
        let schemaInputs = schemaInputs ?? self.createSchema().inputs
        
        self.inputsObservers = self.refreshInputs(schemaInputs: schemaInputs)
        self.outputsObservers = self.refreshOutputs()
        self.canvas.syncRowViewModels(inputRowObservers: self.inputsObservers,
                                      outputRowObservers: self.outputsObservers,
                                      activeIndex: activeIndex)
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

extension StitchComponentViewModel {
    @MainActor
    var id: NodeId {
        guard let node = self.nodeDelegate else {
            fatalErrorIfDebug()
            return .init()
        }
        
        return node.id
    }
    
    @MainActor func evaluate() -> EvalResult? {
        guard let firstGraphState = self.graphs.first else {
            fatalErrorIfDebug()
            return nil
        }
        
        let sampleGraphEntity = firstGraphState.lastEncodedDocument

        // Loop of components is equal to the longest loop length of incoming values
        let loopLength = self.inputsObservers.reduce(into: 1) { result, inputObserver in
            result = max(result, inputObserver.allLoopedValues.count)
        }
        
        // Make sure graph counts match loop length
        self.graphs.adjustArrayLength(to: loopLength) {
            var nodes = NodesViewModelDict()
            for nodeEntity in sampleGraphEntity.nodes {
                // TODO: need to test if the GraphState in nested component gets created in this call
                let nodeType = NodeViewModelType(from: nodeEntity.nodeTypeEntity,
                                                 nodeId: nodeEntity.id)
                
                let newNode = NodeViewModel(from: nodeEntity,
                                         nodeType: nodeType)
                
                nodes.updateValue(newNode, forKey: newNode.id)
            }
            
            let graph = GraphState(from: sampleGraphEntity,
                                   localPosition: ABSOLUTE_GRAPH_CENTER,
                                   nodes: nodes,
                                   components: firstGraphState.components,
                                   mediaFiles: [],  // copy this in next call
                                   saveLocation: firstGraphState.saveLocation)
            graph.mediaLibrary = firstGraphState.mediaLibrary
            return graph
        }
        
        for graph in self.graphs {
            // Update splitters
            let splitterInputs = Self.getInputSplitters(graph: graph)
            
            assertInDebug(splitterInputs.count == self.inputsObservers.count)
            
            // Update graph's inputs before calculating full graph
            zip(splitterInputs, self.inputsObservers).forEach { splitter, input in
                splitter.updateValuesInInput(input.allLoopedValues)
            }
            
            graph.runGraphAndUpdateUI(from: graph.allNodesToCalculate)
        }
        
        
        return self.evaluateOutputSplitters()
    }
    
    @MainActor
    /// Used in capacities where output splitters may have been updated, allowing us to start eval again from this graph.
    func evaluateOutputSplitters() -> EvalResult {
        // Returns [[[PortValue]]], or a list of PortValuesList, of all the splitter output values in each graph (which we'll remap after)
        let allSplitterOutputs = self.graphs.map { graph in
            Self.getOutputSplitters(graph: graph).values
        }
        
        let splittersCount = allSplitterOutputs.first?.count ?? 0
        let splitterOutputsValues = (0..<splittersCount).reduce(into: PortValuesList()) { result, index in
            // Get all values at this port and then flatten
            let outputValuesAtPort = allSplitterOutputs.flatMap { $0[index] }
            result.append(outputValuesAtPort)
        }
        
        assertInDebug(splitterOutputsValues.count == self.outputsObservers.count)
        assertInDebug(splitterOutputsValues.count == self.graphs.count)
        
        // Update outputs here after graph calculation
        zip(splitterOutputsValues, self.outputsObservers).enumerated().forEach { index, data in
            let (splitterValues, outputObserver) = data
            guard let graph = self.graphs[safe: index] else {
                fatalErrorIfDebug()
                return
            }
            
            outputObserver.updateValuesInOutput(splitterValues, graph: graph)
        }
        
        return .init(outputsValues: self.outputsObservers.map(\.allLoopedValues))
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

extension GraphState {
    /// Captures parent graph state in event this graph state is used for component.
    @MainActor
    var parentGraph: GraphState? {
        guard let parentComponentDelegate = self.documentEncoderDelegate as? ComponentEncoder,
              let parentGraph = parentComponentDelegate.delegate?.parentGraph else {
                  return nil
        }
        
        return parentGraph
    }
    
    @MainActor
    func evaluateComponentOutputs() {
        assertInDebug(!self.saveLocation.isEmpty)
        
        guard let parentGraph = self.parentGraph,
              // TODO: is this accurate? we're using a GraphState.id to retrieve a node in the parentGraph?
              let node = parentGraph.nodes.get(self.id.value),
              let componentNode = node.componentNode else {
            fatalErrorIfDebug()
                  return
        }
        
        let prevOutputs = node.outputs
        let evalResult = componentNode.evaluateOutputSplitters()
        
        let changedDownstreamInputs = parentGraph
            .getChangedDownstreamInputIds(evalResult: evalResult,
                                          sourceNode: node,
                                          existingOutputsValues: prevOutputs,
                                          outputCoordinates: node.outputCoordinates)
        
        let downstreamNodes = changedDownstreamInputs.map(\.nodeId).toSet
        
        // Calculate connections from component outputs
        parentGraph.runGraphAndUpdateUI(from: downstreamNodes)
    }
}

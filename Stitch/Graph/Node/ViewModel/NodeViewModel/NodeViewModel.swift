//
//  NodeViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/12/23.
//

import Combine
import Foundation
import SwiftUI
import StitchSchemaKit
import StitchEngine

typealias NodeId = NodeViewModel.ID
typealias NodeIdSet = Set<NodeId>
typealias NodesViewModelDict = [NodeId: NodeViewModel]

@Observable
final class NodeViewModel: Sendable {
    static let fakeId = UUID()
    static let fakeTitle = "None"

    let id: NodeEntity.ID
    
    // constant for perf, since previous solution required observers
    let kind: NodeKind
    
    @MainActor
    var title: String {
        didSet(oldValue) {
            if oldValue != title {
                self._cachedDisplayTitle = self.getDisplayTitle()
            }
        }
    }

    /*
     human-readable-string is perf-intensive, so we cache the node title.

     Previously we used a `lazy var`, but since Swift never recalculates lazy vars we had to switch to a cache.
     */
    @MainActor private var _cachedDisplayTitle: String = ""

    @MainActor
    var nodeType: NodeViewModelType
    
    // Cached for perf
    @MainActor
    var longestLoopLength: Int = 1
    
    @MainActor
    var ephemeralObservers: [any NodeEphemeralObservable]?

    // aka reference to a limited subset of GraphState properties
    @MainActor
    weak var graphDelegate: GraphState?

    /// Called when initializing delegate
    @MainActor
    func syncEphemeralObservers() {
        if self.ephemeralObservers == nil,
           let ephemeralObserver = self.createEphemeralObserver() {
            self.ephemeralObservers = [ephemeralObserver]
        }
    }
    
    @MainActor
    init(from schema: NodeEntity,
         nodeType: NodeViewModelType) {
        self.id = schema.id
        self.title = schema.title
        self.nodeType = nodeType
        self.kind = nodeType.kind
        
        self._cachedDisplayTitle = self.getDisplayTitle()
    }
    
    // i.e. "create node view model from schema
    @MainActor
    convenience init(from schema: NodeEntity,
                     components: [UUID : StitchMasterComponent],
                     parentGraphPath: [UUID]) async {
        let nodeType = await NodeViewModelType(from: schema.nodeTypeEntity,
                                               nodeId: schema.id,
                                               components: components,
                                               parentGraphPath: parentGraphPath)
        self.init(from: schema,
                  nodeType: nodeType)
    }
    
    @MainActor
    convenience init(from schema: NodeEntity,
                     graphDelegate: GraphState,
                     document: StitchDocumentViewModel) async {
        await self.init(from: schema,
                        components: graphDelegate.components,
                        parentGraphPath: graphDelegate.saveLocation)
        self.initializeDelegate(graph: graphDelegate,
                                document: document)
    }
}


extension NodeViewModel {
    @MainActor
    func userVisibleTypeChanged(oldType: UserVisibleType,
                                newType: UserVisibleType) {
        self.ephemeralObservers?.forEach {
            $0.nodeTypeChanged(oldType: oldType,
                               newType: newType,
                               kind: self.kind)
        }
    }
}

extension NodeViewModel {
    @MainActor static func createEmpty() -> Self {
        .init()
    }
    
    @MainActor
    convenience init() {
        let nodeEntity = NodeEntity(id: .init(),
                                    nodeTypeEntity: .group(.init(position: .zero,
                                                                 zIndex: .zero,
                                                                 parentGroupNodeId: nil)),
                                    title: "")
        
        self.init(from: nodeEntity,
                  nodeType: .group(.init(id: .node(.init()),
                                         position: .zero,
                                         zIndex: .zero,
                                         parentGroupNodeId: nil,
                                         inputRowObservers: [],
                                         outputRowObservers: [])))
    }
    
    @MainActor
    func initializeDelegate(graph: GraphState,
                            document: StitchDocumentViewModel) {
        self.graphDelegate = graph
        self.nodeType.initializeDelegate(self,
                                         components: graph.components,
                                         document: document)
        self.syncEphemeralObservers()
    }
    
    @MainActor
    var computedStates: [ComputedNodeState]? {
        self.ephemeralObservers?.compactMap {
            $0 as? ComputedNodeState
        }
    }

    @MainActor
    func createEphemeralObserver() -> NodeEphemeralObservable? {
        let observer = self.kind.graphNode?.createEphemeralObserver()
        
        // Media eval observers need reference to a node delegate
        if let mediaObserver = observer as? any MediaEvalOpObservable {
            mediaObserver.nodeDelegate = self
            return mediaObserver
        }
        
        return observer
    }
    
    @MainActor
    func getAllCanvasObservers() -> [CanvasItemViewModel] {
        switch nodeType {
        case .patch(let patchNode):
            return [patchNode.canvasObserver]
        case .layer(let layerNode):
            return layerNode.getAllCanvasObservers()
        case .group(let canvasObserver):
            return [canvasObserver]
        case .component(let component):
            return [component.canvas]
        }
    }
    
    @MainActor
    func getCanvasObserver(for id: CanvasItemId) -> CanvasItemViewModel? {
        switch nodeType {
        case .patch(let patchNode):
            assertInDebug(patchNode.canvasObserver.id == id)
            return patchNode.canvasObserver
        
        case .layer(let layerNode):
            switch id {
            case .layerInput(let layerInput):
                return layerNode[keyPath: layerInput.keyPath.layerNodeKeyPath].canvasObserver
                
            case .layerOutput(let layerOutput):
                return layerNode.outputPorts[safe: layerOutput.portId]?.canvasObserver
                
            case .node:
                fatalErrorIfDebug("Node case not supported for layers")
                return nil
            }
        
        case .group, .component:
            return self.patchCanvasItem
        }
    }
    
    @MainActor
    var patchCanvasItem: CanvasItemViewModel? {
        switch nodeType {
        case .patch(let patchNode):
            return patchNode.canvasObserver
        case .layer:
            return nil
        case .group(let canvasObserver):
            return canvasObserver
        case .component(let component):
            return component.canvas
        }
    }
    
    /// Checks if any canvas entity for this node is visible.
    @MainActor
    func isVisibleInFrame(_ visibleCanvasIds: CanvasItemIdSet,
                          _ selectedSidebarLayers: SidebarLayerIdSet) -> Bool {
        for canvasObserver in self.getAllCanvasObservers() {
            if canvasObserver.isVisibleInFrame(visibleCanvasIds) {
                return true
            }
        }
        
        // Check for visible layer inspectors
        if let layerId = self.layerNode?.id,
           selectedSidebarLayers.contains(layerId) {
            return true
        }
        
        return false
    }
    
    @MainActor func getValidCustomTitle() -> String? {
        guard self.kind.isEligibleForDefaultTitleDisplay else { return nil }
        
        let defaultTitle = self.kind.getDisplayTitle(customName: nil)
        let hasCustomTitle = self.displayTitle.trim() != defaultTitle.trim()
        
        guard hasCustomTitle else { return nil }
        return defaultTitle
    }
    
    @MainActor var hasLargeCanvasTitleSpace: Bool {
        let hasMathFormula = !(self.patchNode?.mathExpression?.isEmpty ?? true)
        
        // Math Expression nodes only adjust height for math formula, not custom title
        if self.kind == .patch(.mathExpression) {
            return hasMathFormula
        }
        
        return self.getValidCustomTitle().isDefined
    }
    
    @MainActor
    func updateOutputsObservers(newValuesList: PortValuesList? = nil, graph: GraphState) {
        let outputsObservers = self.getAllOutputsObservers()
        
        if let newValuesList = newValuesList {
            updateRowObservers(rowObservers: outputsObservers,
                               newIOValues: newValuesList)
        }

        zip(outputsObservers, newValuesList ?? self.outputs).forEach { rowObserver, values in
            rowObserver.updateValuesInOutput(values, graph: graph)
        }
    }

    /// Retrieves a GroupNode's underlying input-splitter.
    @MainActor
    func getInputRowObserverForUI(for portType: NodeIOPortType,
                                  _ graph: GraphState) -> InputNodeRowObserver? {
        switch portType {
        
        case .portIndex(let portId):
            // LayerNode inputs NEVER use portId, only keyPath
            assertInDebug(!self.nodeType.kind.getLayer.isDefined)
            return self.getAllInputsObserversForUI(graph)[safe: portId]
            
        case .keyPath:
            return self.getInputRowObserver(for: portType)
        }
    }
    
    @MainActor
    func getInputRowObserver(_ portId: Int) -> InputNodeRowObserver? {
        self.getInputRowObserver(for: .portIndex(portId))
    }
    
    @MainActor
    func getInputRowObserver(for portType: NodeIOPortType) -> InputNodeRowObserver? {
        
        switch portType {
        
        case .portIndex(let portId):
            return self.getAllInputsObservers()[safe: portId]
        
        case .keyPath(let keyPath):
            // For layer inputs, prefer accessing via Swift keyPath
            guard let layerNode = self.layerNode else {
                fatalErrorIfDebug()
                return nil
            }
            return layerNode[keyPath: keyPath.layerNodeKeyPath].rowObserver
        }
    }
    
    @MainActor
    func getOutputRowObserverForUI(for portId: Int,
                                   _ graph: GraphState) -> OutputNodeRowObserver? {
        self.getAllOutputsObserversForUI(graph)[safe: portId]
    }
    
    // TODO: reintroduce difference between `OutputCoordinate(portId: Int, NodeId)` and `InputCoordinate(portType: NodeIOPortType, NodeId)`; probably best introduced at the Input- vs OutputNodeRowObserver level.
    @MainActor
    func getOutputRowObserver(for portType: NodeIOPortType) -> OutputNodeRowObserver? {
        guard let portId = portType.portId else {
            fatalErrorIfDebug("Attempted to retrieve an output observer using a layer input?")
            return nil
        }
        return self.getAllOutputsObservers()[safe: portId]
    }
    
    @MainActor
    func getOutputRowObserver(for portId: Int) -> OutputNodeRowObserver? {
        self.getAllOutputsObservers()[safe: portId]
    }
    
    @MainActor
    func getInputRowViewModel(for id: NodeRowViewModelId) -> InputNodeRowViewModel? {
        switch id.graphItemType {
        case .node(let canvasId):
            let canvas = self.getCanvasObserver(for: canvasId)
            return canvas?.inputViewModels[safe: id.portId]
            
        case .layerInspector(let portType):
            guard let layerNode = self.layerNode else {
                fatalErrorIfDebug()
                return nil
            }
            
            switch portType {
            case .portIndex:
                fatalErrorIfDebug("unexpected port index for input view model getter")
                return nil
                
            case .keyPath(let keyPath):
                let inputData = layerNode[keyPath: keyPath.layerNodeKeyPath]
                return inputData.inspectorRowViewModel
            }
        }
    }
    
    @MainActor
    func getOutputRowViewModel(for id: NodeRowViewModelId) -> OutputNodeRowViewModel? {
        switch id.graphItemType {
        case .node(let canvasId):
            let canvas = self.getCanvasObserver(for: canvasId)
            return canvas?.outputViewModels[safe: id.portId]
            
        case .layerInspector(let portType):
            guard let layerNode = self.layerNode else {
                fatalErrorIfDebug()
                return nil
            }
            
            switch portType {
            case .keyPath:
                fatalErrorIfDebug("unexpected keypath for output view model getter")
                return nil
                
            case .portIndex(let portId):
                let outputData = layerNode.outputPorts[safe: portId]
                return outputData?.inspectorRowViewModel
            }
        }
    }
    
    @MainActor
    var color: NodeUIColor {
        switch self.kind {
        case .patch(let patch):
            return derivePatchNodeColor(
                for: patch,
                splitterType: self.splitterType)
        default:
            return .commonNodeColor
        }
    }

    @MainActor
    var displayTitle: String {
        guard self.id != Self.fakeId else {
            return Self.fakeTitle
        }

        return self._cachedDisplayTitle
    }
    
    // Returns indices of LONGEST LOOP
    @MainActor
    func getLoopIndices() -> [Int] {
        let inputValuesList = self.inputs
        let outputValuesList = self.outputs

        switch self.nodeType {
        case .patch, .layer:
            if self.kind.getPatch?.usesInputsForLoopIndices ?? false {
                return getLongestLoopIndices(valuesList: inputValuesList)
            } else {
                return outputValuesList.isEmpty
                    ? getLongestLoopIndices(valuesList: inputValuesList)
                    : getLongestLoopIndices(valuesList: outputValuesList)
            }

        case .group, .component:
            return []
        }
    }
}

extension NodeViewModel {
    @MainActor
    var inputsRowCount: Int {
        self.getAllInputsObservers().count
    }
    
    @MainActor
    var outputsRowCount: Int {
        self.getAllOutputsObservers().count
    }
    
    @MainActor
    var getMathExpression: String? {
        self.patchNode?.mathExpression
    }
    
    @MainActor var allInputViewModels: [InputNodeRowViewModel] {
        switch self.nodeType {
        case .patch(let patch):
            return patch.canvasObserver.inputViewModels
        
        case .group(let canvas):
            return canvas.inputViewModels
            
        case .component(let component):
            return component.canvas.inputViewModels
            
        case .layer(let layer):
            return layer.layer.layerGraphNode.inputDefinitions.flatMap {
                let inputPort = layer[keyPath: $0.layerNodeKeyPath]
                
                return inputPort.allInputData.flatMap { inputData in
                    if let canvas = inputData.canvasObserver {
                        return canvas.inputViewModels + [inputData.inspectorRowViewModel]
                    }
                    
                    return [inputData.inspectorRowViewModel]
                }
            }
        }
    }
    
    @MainActor var allOutputViewModels: [OutputNodeRowViewModel] {
        switch self.nodeType {
        case .patch(let patch):
            return patch.canvasObserver.outputViewModels
        
        case .group(let canvas):
            return canvas.outputViewModels
            
        case .component(let component):
            return component.canvas.outputViewModels
            
        case .layer(let layer):
            return layer.outputPorts.flatMap { outputData in
                if let canvas = outputData.canvasObserver {
                    return canvas.outputViewModels + [outputData.inspectorRowViewModel]
                }
                
                return [outputData.inspectorRowViewModel]
            }
        }
    }
}


extension NodeViewModel {
    // MARK: main actor needed to prevent view updates from background thread
    @MainActor
    func update(from schema: NodeEntity,
                components: [UUID : StitchMasterComponent],
                activeIndex: ActiveIndex) async {
        await self.nodeType.update(from: schema.nodeTypeEntity,
                                   components: components,
                                   activeIndex: activeIndex)
        
        self.updateTitle(newTitle: schema.title)
    }
    
    @MainActor
    func updateTitle(newTitle: String) {
        if self.title != newTitle {
            self.title = newTitle
        }
        
        if self._cachedDisplayTitle != self.getDisplayTitle() {
            self._cachedDisplayTitle = self.getDisplayTitle()
        }
    }
    
    @MainActor
    func update(from schema: NodeEntity) {
        self.nodeType.update(from: schema.nodeTypeEntity)
        self.updateTitle(newTitle: schema.title)
    }

    @MainActor func createSchema() -> NodeEntity {
        NodeEntity(id: self.id,
                   nodeTypeEntity: self.nodeType.createSchema(),
                   title: self.title)
    }
    
    @MainActor func onPrototypeRestart(document: StitchDocumentViewModel) {
        // Reset ephemeral observers
        self.ephemeralObservers?.forEach {
            $0.onPrototypeRestart(document: document)
        }
        
        // Reset outputs
        // TODO: should we really be resetting inputs?
        self.getAllInputsObservers().onPrototypeRestart(document: document)
        self.getAllOutputsObservers().forEach { $0.onPrototypeRestart(document: document) }
        
        // Reset properties specific to the node's actual type (patch vs layer vs component vs group)
        self.nodeType.onPrototypeRestart(document: document)
    }
}

extension NodeViewModel: Identifiable { }

extension NodeViewModel {
    @MainActor
    func activeIndexChanged(activeIndex: ActiveIndex) {
        self.getAllInputsObservers().forEach { observer in
            let oldValue = observer.getActiveValue(activeIndex: activeIndex)
            let newValue = PortValue
                .getActiveValue(allLoopedValues: observer.allLoopedValues,
                                activeIndex: activeIndex)
            observer.allRowViewModels.forEach {
                $0.activeValueChanged(oldValue: oldValue,
                                      newValue: newValue)
            }
        }

        self.getAllOutputsObservers().forEach { observer in
            let oldValue = observer.getActiveValue(activeIndex: activeIndex)
            let newValue = PortValue
                .getActiveValue(allLoopedValues: observer.allLoopedValues,
                                activeIndex: activeIndex)
            observer.allRowViewModels.forEach {
                $0.activeValueChanged(oldValue: oldValue, newValue: newValue)
            }
        }
    }
    
    @MainActor
    var inputPortCount: Int {
        switch self.nodeType {
        case .layer(let layerNode):
            return layerNode.layer
                .layerGraphNode.inputDefinitions.count
        case .group(let canvas):
            return canvas.inputViewModels.count
        case .component(let component):
            return component.canvas.inputViewModels.count
        case .patch(let patchNode):
            return patchNode.inputsObservers.count
        }
    }
    
    // See https://github.com/vpl-codesign/stitch/issues/5148
    @MainActor
    func inputsWithoutImmediatelyUpstreamInteractionNode(_ nodes: NodesViewModelDict) -> PortValuesList {
        self.getAllInputsObservers()
            .filter { $0.hasUpstreamInteractionNode(nodes) }
            .map(\.allLoopedValues)
    }
    
    @MainActor
    func updateOutput(_ values: PortValues,
                      at portId: Int,
                      activeIndex: ActiveIndex) {
        guard self.outputs.count > portId else {
            log("PatchNode: portID exceeds outputs count")
            return
        }

        guard let graph = self.graphDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        self.getAllOutputsObservers()[safe: portId]?.updateValuesInOutput(values, graph: graph)
    }
    
    // don't worry about making the input a loop or not --
    // the extension will happen at eval-time
    @MainActor
    func inputAdded() {
        guard let patchNode = self.patchNode else {
            fatalErrorIfDebug()
            return
        }
        
        
        guard let graph = self.graphDelegate,
              let document = graph.documentDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        // assumes new input has no label, etc.
        log("inputAdded called")
        let allInputsObservers = self.getAllInputsObservers()

        // New value needs to be a default of same type as other inputs
        // Grab the type's default, based on value of last input;
        // Last input should be the type of the expandable input
        // (vs. first input on optionPicker

        guard let lastRowObserver = allInputsObservers.last else {
            fatalErrorIfDebug()
            return
        }
        
        let newInputCoordinate = InputCoordinate(portId: allInputsObservers.count,
                                                 nodeId: self.id)
        let newInputObserver = InputNodeRowObserver(values: lastRowObserver.allLoopedValues,
                                                    id: newInputCoordinate,
                                                    upstreamOutputCoordinate: nil)
        
        let newRowId = NodeRowViewModelId(graphItemType: .node(patchNode.canvasObserver.id),
                                          nodeId: newInputCoordinate.nodeId,
                                          portId: allInputsObservers.count)
        
        let newInputViewModel = InputNodeRowViewModel(
            id: newRowId,
            initialValue: newInputObserver.getActiveValue(activeIndex: document.activeIndex),
            rowDelegate: newInputObserver,
            canvasItemDelegate: patchNode.canvasObserver)
        
        patchNode.inputsObservers.append(newInputObserver)
        patchNode.canvasObserver.inputViewModels.append(newInputViewModel)
        
        // Assign delegates once view models are assigned to node
        newInputObserver.initializeDelegate(self, graph: graph)
        newInputViewModel.initializeDelegate(
            self,
            initialValue: newInputObserver.getActiveValue(activeIndex: document.activeIndex),
            // Only relevant for layer nodes, which cannot have an input added or removed
            unpackedPortParentFieldGroupType: nil,
            unpackedPortIndex: nil,
            layerInput: nil)
    }

    @MainActor
    func inputRemoved(minimumInputs: Int) {
        guard let patchNode = self.patchNode else {
            fatalErrorIfDebug()
            return
        }
        
        // assumes new input has no label, etc.
        log("inputRemoved called")
        
        guard self.getAllInputsObservers().count > minimumInputs else {
            return
        }

        if let removedInputObserver = patchNode.inputsObservers.last {
            patchNode.inputsObservers = patchNode.inputsObservers.dropLast()
            
            // Remove input view models--fixes behavior for input edit mode
            let inputViewModels = removedInputObserver.allRowViewModels
            for input in inputViewModels {
                if let canvas = input.canvasItemDelegate {
                    canvas.inputViewModels = canvas.inputViewModels.filter {
                        $0.id != input.id
                    }
                }
            }
        }
    }
    
    @MainActor func flattenOutputs() {
        self.getAllOutputsObservers().flattenOutputs()
    }
    
    @MainActor
    func appendInputRowObserver(_ rowObserver: InputNodeRowObserver) {
        guard let patchNode = self.patchNode else {
            fatalErrorIfDebug()
            return
        }
        
        patchNode.inputsObservers.append(rowObserver)
    }
}

extension Array where Element: NodeRowObserver {
    @MainActor func flattenOutputs() {
        self.forEach { output in
            if let firstValue = output.allLoopedValues.first {
                output.allLoopedValues = [firstValue]
            }
        }
    }
}

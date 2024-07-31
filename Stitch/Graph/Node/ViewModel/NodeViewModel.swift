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
    // Create some fake patch node as our "nil" choice for dropdowns like layers, broadcast nodes
    @MainActor
    static let nilChoice = SplitterPatchNode.createViewModel(
        position: .zero,
        zIndex: .zero,
        activeIndex: .init(.zero),
        graphDelegate: nil)

    var id: NodeEntity.ID
    
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
    private var _cachedDisplayTitle: String = ""

    var nodeType: NodeViewModelType
    
    // Cached for perf
    var longestLoopLength: Int = 1
    var ephemeralObservers: [any NodeEphemeralObservable]?

    // aka reference to a limited subset of GraphState properties
    weak var graphDelegate: GraphDelegate?

    @MainActor
    static func createNodeViewModelFromSchema(_ nodeSchema: NodeEntity,
                                              activeIndex: ActiveIndex,
                                              graphDelegate: GraphDelegate) -> NodeViewModel {
        let node = NodeViewModel(from: nodeSchema,
                                 activeIndex: activeIndex)
        node.initializeDelegate(graph: graphDelegate)
        return node
    }

    /// Called on initialization or prototype restart.
    @MainActor
    func createEphemeralObservers() {
        if let ephemeralObserver = self.createEphemeralObserver() {
            self.ephemeralObservers = [ephemeralObserver]
        }
    }
    
    // i.e. "create node view model from schema
    @MainActor
    init(from schema: NodeEntity,
         activeIndex: ActiveIndex) {
        self.id = schema.id
        self.title = schema.title
        self.nodeType = NodeViewModelType(from: schema.nodeTypeEntity,
                                          nodeId: schema.id)
        
        self._cachedDisplayTitle = self.getDisplayTitle()
    }
    
    @MainActor
    convenience init(from schema: NodeEntity,
                     activeIndex: ActiveIndex,
                     graphDelegate: GraphDelegate) {
        self.init(from: schema,
                  activeIndex: activeIndex)
        self.initializeDelegate(graph: graphDelegate)
    }
}

extension NodeViewModel: NodeCalculatable {
    @MainActor func getAllInputsObservers() -> [InputNodeRowObserver] {        
        switch self.nodeType {
        case .patch(let patch):
            return patch.inputsObservers
        case .layer(let layer):
            return layer.getSortedInputObservers()
        case .group(let canvas):
            return canvas.inputViewModels.compactMap {
                $0.rowDelegate
            }
        }
    }
    
    @MainActor func getAllOutputsObservers() -> [OutputNodeRowObserver] {        
        switch self.nodeType {
        case .patch(let patch):
            return patch.outputsObservers
        case .layer(let layer):
            return layer.outputPorts.map { $0.rowObserver }
        case .group(let canvas):
            return canvas.outputViewModels.compactMap {
                $0.rowDelegate
            }
        }
    }
    
    // after we eval a node, we sets its current inputs to be its previous inputs,
    // so that we know we've run the node once,
    // and so that we won't run the node again until at least one of the inputs has changed
    
    // If unable to run eval for a node (e.g. because it is one of the layer nodes that does not support node eval),
    // return `nil` rather than an empty list of inputs
    @MainActor func evaluate() -> EvalResult? {
        switch self.nodeType {
        case .patch(let patchNodeViewModel):
            return patchNodeViewModel.patch.evaluate.runEvaluation(
                node: self
            )
            
        case .layer(let layerNodeViewModel):
            // Only a handful of layer nodes have node evals
            if let eval = layerNodeViewModel.layer.evaluate {
                return eval.runEvaluation(
                    node: self
                )
            } else {
                return nil
            }
            
        case .group:
#if DEBUG
            fatalErrorIfDebug()
#endif
            return nil
        }
    }
    
    @MainActor
    func inputsWillUpdate(values: PortValuesList) {
        // update cache for longest loop length
        self.longestLoopLength = self.kind.determineMaxLoopCount(from: values)
        
        // Updates preview layers if layer specified
        // Must be before runEval check below since most layers don't have eval!
        self.layerNode?.didValuesUpdate(newValuesList: values,
                                        id: self.id)
    }
    
    @MainActor func outputsUpdated(evalResult: EvalResult) {
        self.updateOutputsObservers(newOutputsValues: evalResult.outputsValues,
                                    activeIndex: graphDelegate?.activeIndex ?? .init(.zero))
        
        // `state.flashes` is for pulses' UI-effects
        var effects = evalResult.effects
        
        // Reverse any fired output pulses
        effects += evalResult
            .outputsValues
            .getPulseReversionEffects(nodeId: self.id,
                                      graphTime: graphDelegate?.graphStepState.graphTime ?? .zero)

        effects.processEffects()
    }
    
    var isGroupNode: Bool {
        self.kind == .group
    }
}

extension NodeViewModel: PatchNodeViewModelDelegate {
    func userVisibleTypeChanged(oldType: UserVisibleType,
                                newType: UserVisibleType) {
        self.ephemeralObservers?.forEach {
            $0.nodeTypeChanged(oldType: oldType,
                               newType: newType,
                               kind: self.kind)
        }
        
        // TODO: get rid of redundant `userVisibleType` on NodeRowObservers or make them access it via NodeDelegate
        if let patchNode = self.patchNode {
            patchNode.inputsObservers.forEach {
                $0.userVisibleType = newType
            }
            
            patchNode.outputsObservers.forEach {
                $0.userVisibleType = newType
            }
        }
    }
}

extension NodeViewModel {
    @MainActor func initializeDelegate(graph: GraphDelegate) {
        self.graphDelegate = graph
        self.nodeType.initializeDelegate(self)
        self.createEphemeralObservers()
    }
    
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
        }
    }
    
    var patchCanvasItem: CanvasItemViewModel? {
        switch nodeType {
        case .patch(let patchNode):
            return patchNode.canvasObserver
        case .layer:
            return nil
        case .group(let canvasObserver):
            return canvasObserver
        }
    }
    
    /// Checks if any canvas entity for this node is visible.
    @MainActor
    var isVisibleInFrame: Bool {
        for canvasObserver in self.getAllCanvasObservers() {
            if canvasObserver.isVisibleInFrame {
                return true
            }
        }
        
        return false
    }
    
    @MainActor
    func updateInputPortViewModels(activeIndex: ActiveIndex) {
        zip(self.getAllInputsObservers(), self.inputs).forEach { rowObserver, values in
            rowObserver.updatePortViewModels(values: values)
        }
    }

    @MainActor
    func updateOutputPortViewModels(activeIndex: ActiveIndex) {
        zip(self.getAllOutputsObservers(), self.outputs).forEach { rowObserver, values in
            rowObserver.updatePortViewModels(values: values)
        }
    }
    
    @MainActor
    func updateOutputsObservers(newValuesList: PortValuesList? = nil,
                                activeIndex: ActiveIndex) {
        let outputsObservers = self.getAllOutputsObservers()
        
        if let newValuesList = newValuesList {
            self.updateRowObservers(rowObservers: outputsObservers,
                                    newIOValues: newValuesList)
        }

        zip(outputsObservers, newValuesList ?? self.outputs).forEach { rowObserver, values in
            rowObserver.updateValues(values)
        }
    }
    
    @MainActor
    func getInputRowObserver(for portType: NodeIOPortType) -> InputNodeRowObserver? {
        switch portType {
        case .portIndex(let portId):
            // Assumes patch node for port ID
            return self.patchNode?.inputsObservers[safe: portId]

        case .keyPath(let keyPath):
            guard let layerNode = self.layerNode else {
                fatalErrorIfDebug()
                return nil
            }
            
            return layerNode[keyPath: keyPath.layerNodeKeyPath].rowObserver
        }
    }

    @MainActor
    func getInputRowObserver(_ portId: Int) -> InputNodeRowObserver? {
        guard let canvas = self.patchCanvasItem else {
            fatalErrorIfDebug("Only intended for patch nodes")
            return nil
        }
        
        return canvas.inputViewModels[safe: portId]?.rowDelegate
    }
    
    @MainActor
    func getInputRowObserver(for layerInputType: LayerInputType) -> InputNodeRowObserver? {
        self.getInputRowObserver(for: .keyPath(layerInputType))
    }
    
    @MainActor
    func getOutputRowObserver(for portType: NodeIOPortType) -> OutputNodeRowObserver? {
        switch portType {
        case .keyPath:
            // No support here
            fatalErrorIfDebug()
            return nil
            
        case .portIndex(let portId):
            return self.patchCanvasItem?.outputViewModels[safe: portId]?.rowDelegate
        }
    }
    
    @MainActor
    func getInputRowViewModel(for id: NodeRowViewModelId) -> InputNodeRowViewModel? {
        self.getAllInputsObservers()
            .flatMap { $0.allRowViewModels }
            .first { $0.id == id }
    }
    
    @MainActor
    func getInputRowViewModel(nodeRowId: NodeRowViewModelId) -> InputNodeRowViewModel? {
        self.getAllInputsObservers()
            .flatMap { $0.allRowViewModels }
            .first { $0.id == id }
    }

    @MainActor
    func getInputRowViewModel(nodeId: NodeId,
                              graphItemType: GraphItemType,
                              portType: NodeIOPortType) -> InputNodeRowViewModel? {
        self.getAllInputsObservers()
            .flatMap { $0.allRowViewModels }
            .first { $0.rowDelegate?.id == .init(portType: portType,
                                                 nodeId: nodeId) }
    }
    
    @MainActor
    func getInputRowViewModel(for id: NodeIOCoordinate,
                              graphItemType: GraphItemType) -> InputNodeRowViewModel? {
        self.getInputRowViewModel(nodeId: id.nodeId,
                                  graphItemType: graphItemType,
                                  portType: id.portType)
    }
    
    @MainActor
    func getOutputRowViewModel(for id: NodeRowViewModelId) -> OutputNodeRowViewModel? {
        self.getAllOutputsObservers()
            .flatMap { $0.allRowViewModels }
            .first { $0.id == id }
    }

    @MainActor
    func getOutputRowObserver(_ portId: Int) -> OutputNodeRowObserver? {
        guard let canvas = self.patchCanvasItem else {
            fatalErrorIfDebug("Only intended for patch nodes")
            return nil
        }
        
        return canvas.outputViewModels[safe: portId]?.rowDelegate
    }
    
    @MainActor
    private func updateRowObservers<RowObserver>(rowObservers: [RowObserver],
                                                 newIOValues: PortValuesList) where RowObserver: NodeRowObserver {
        
        newIOValues.enumerated().forEach { portId, newValues in
            guard let observer = rowObservers[safe: portId] else {
#if DEV_DEBUG
                log("NodeViewModel.initializeThrottlers error: no observer found, this shouldn't happen.")
                log("NodeViewModel.initializeThrottlers: error: node.id: \(self.id)")
                log("NodeViewModel.initializeThrottlers: error: portId: \(portId)")
#endif
                return
            }
            
            observer.updateValues(newValues)
        }
    }
    
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
        guard self.id != Self.nilChoice.id else {
            return "None"
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

        case .group:
            return []
        }
    }
}

extension NodeViewModel: NodeDelegate {    
    func portCountShortened(to length: Int, nodeIO: NodeIO) {
        self.patchNodeViewModel?.portCountShortened(to: length,
                                                    nodeIO: nodeIO)
    }
    
    var inputsRowCount: Int {
        self.getAllInputsObservers().count
    }
    
    var outputsRowCount: Int {
        self.getAllOutputsObservers().count
    }
    
    var activeIndex: ActiveIndex {
        graphDelegate?.activeIndex ?? .init(.zero)
    }

    // TODO: where is this used? Why would an input be retrieving some other node from GraphState? Why not just grab from GraphState directly?
    func getNode(_ id: NodeId) -> NodeViewModel? {
        self.graphDelegate?.getNodeViewModel(id)
    }
    
    var getMathExpression: String? {
        self.patchNode?.mathExpression
    }
    
    @MainActor var allInputViewModels: [InputNodeRowViewModel] {
        switch self.nodeType {
        case .patch(let patch):
            return patch.canvasObserver.inputViewModels
        
        case .group(let canvas):
            return canvas.inputViewModels
            
        case .layer(let layer):
            return layer.layer.layerGraphNode.inputDefinitions.flatMap {
                let inputData = layer[keyPath: $0.layerNodeKeyPath]
                
                if let canvas = inputData.canvasObserver {
                    return canvas.inputViewModels + [inputData.inspectorRowViewModel]
                }
                
                return [inputData.inspectorRowViewModel]
            }
        }
    }
    
    @MainActor var allOutputViewModels: [OutputNodeRowViewModel] {
        switch self.nodeType {
        case .patch(let patch):
            return patch.canvasObserver.outputViewModels
        
        case .group(let canvas):
            return canvas.outputViewModels
            
        case .layer(let layer):
            // For old layer node we temporarily stuff the canvas item in its position port
            if !FeatureFlags.USE_LAYER_INSPECTOR {
                return layer.positionPort.canvasObserver?.outputViewModels ?? []
            } else {
                return layer.outputPorts.flatMap {
                    return $0.canvasObserver?.outputViewModels ?? []
                }
            }
        }
    }
}


extension NodeViewModel: SchemaObserver {
    @MainActor
    static func createObject(from entity: NodeEntity) -> Self {
        return .init(from: entity,
                     activeIndex: .init(.zero))
    }

    // MARK: main actor needed to prevent view updates from background thread
    @MainActor
    func update(from schema: NodeEntity) {
        self.nodeType.update(from: schema.nodeTypeEntity)

        if self.title != schema.title {
            self.title = schema.title
        }
        
        if self._cachedDisplayTitle != self.getDisplayTitle() {
            self._cachedDisplayTitle = self.getDisplayTitle()
        }
    }

    func createSchema() -> NodeEntity {
        NodeEntity(id: self.id,
                   nodeTypeEntity: self.nodeType.createSchema(),
                   title: self.title)
    }
    
    func onPrototypeRestart() {
        // Reset ephemeral observers
        self.createEphemeralObservers()
        
        // Reset outputs
        // TODO: should we really be resetting inputs?
        self.getAllInputsObservers().onPrototypeRestart()
        self.getAllOutputsObservers().forEach { $0.onPrototypeRestart() }
        
        // Flatten interaction nodes' outputs when graph reset
        if patchNode?.patch.isInteractionPatchNode ?? false {
            self.flattenOutputs()
        }
    }
}

extension NodeViewModel: Identifiable { }

extension NodeViewModel {
    @MainActor
    func activeIndexChanged(activeIndex: ActiveIndex) {
        self.getAllInputsObservers().forEach { observer in
            let oldValue = observer.activeValue
            let newValue = PortValue
                .getActiveValue(allLoopedValues: observer.allLoopedValues,
                                activeIndex: activeIndex)
            observer.allRowViewModels.forEach {
                $0.activeValueChanged(oldValue: oldValue,
                                      newValue: newValue)
            }
        }

        self.getAllOutputsObservers().forEach { observer in
            let oldValue = observer.activeValue
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

        self.getAllOutputsObservers()[safe: portId]?.updateValues(values)
    }

    @MainActor
    func updateOutputsObservers(newOutputsValues: PortValuesList,
                                activeIndex: ActiveIndex) {
        self.getAllOutputsObservers()
            .updateAllValues(newOutputsValues,
                             nodeId: self.id,
                             nodeKind: self.kind,
                             userVisibleType: self.userVisibleType,
                             nodeDelegate: self,
                             activeIndex: activeIndex)
    }
    
    // don't worry about making the input a loop or not --
    // the extension will happen at eval-time
    @MainActor
    func inputAdded() {
        guard let patchNode = self.patchNode else {
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
                                                    nodeKind: self.kind,
                                                    userVisibleType: self.userVisibleType,
                                                    id: newInputCoordinate,
                                                    activeIndex: self.activeIndex,
                                                    upstreamOutputCoordinate: nil)
        newInputObserver.initializeDelegate(self)
        
        let newInputViewModel = InputNodeRowViewModel(id: .init(graphItemType: .node(patchNode.canvasObserver.id),
                                                                nodeId: newInputCoordinate.nodeId,
                                                                portId: allInputsObservers.count),
                                                      activeValue: newInputObserver.activeValue,
                                                      rowDelegate: newInputObserver,
                                                      canvasItemDelegate: patchNode.canvasObserver)
        newInputViewModel.initializeDelegate(self)
        
        patchNode.inputsObservers.append(newInputObserver)
        patchNode.canvasObserver.inputViewModels.append(newInputViewModel)
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

        patchNode.inputsObservers = patchNode.inputsObservers.dropLast()
    }
    
    @MainActor func flattenOutputs() {
        self.getAllOutputsObservers().forEach { output in
            if let firstValue = output.allLoopedValues.first {
                output.allLoopedValues = [firstValue]
            }
        }
    }
    
    func appendInputRowObserver(_ rowObserver: InputNodeRowObserver) {
        guard let patchNode = self.patchNode else {
            fatalErrorIfDebug()
            return
        }
        
        patchNode.inputsObservers.append(rowObserver)
    }
}

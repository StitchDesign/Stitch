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
                                              graphDelegate: GraphDelegate?) -> NodeViewModel {
        NodeViewModel(from: nodeSchema,
                      activeIndex: activeIndex,
                      graphDelegate: graphDelegate)
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
         activeIndex: ActiveIndex,
         graphDelegate: GraphDelegate?) {
        self.id = schema.id
        self.title = schema.title
        self.nodeType = NodeViewModelType(from: schema.nodeEntityType,
                                          nodeDelegate: nil)
        self._cachedDisplayTitle = self.getDisplayTitle()
        
        // Set delegates
        self.graphDelegate = graphDelegate
        self.getAllCanvasObservers().forEach {
            $0.nodeDelegate = self
        }
        self.getAllInputsObservers().forEach {
            $0.nodeDelegate = self
        }
        self.getAllOutputsObservers().forEach {
            $0.nodeDelegate = self
        }

        self.createEphemeralObservers()
        
        switch self.nodeType {
        case .patch(let patchNode):
            patchNode.delegate = self

        case .layer(let layerNode):
            layerNode.nodeDelegate = self
            
//            // Layer nodes use key paths instead of array for input observers
//            for inputType in layerNode.layer.layerGraphNode.inputDefinitions {
//                guard let layerNodeEntity = schema.nodeEntityType.layerNodeEntity else {
//                    fatalErrorIfDebug()
//                    return
//                }
//                
//                // Set delegate and call update values helper
//                let rowObserver = layerNode[keyPath: inputType.layerNodeKeyPath].rowObserver
//                let rowSchema = layerNodeEntity[keyPath: inputType.schemaPortKeyPath]
//                rowObserver.nodeDelegate = self
//                
//                assertInDebug(!rowObserver.allLoopedValues.isEmpty)
//            }

            // Initialize layers
            self.layerNode?.didValuesUpdate(newValuesList: self.inputs,
                                            id: self.id)
        default:
            return
            
        }
    }
    
    @MainActor
    convenience init(id: NodeId,
                     position: CGSize = .zero,
                     zIndex: Double = .zero,
                     customName: String? = nil,
                     inputs: PortValuesList,
                     inputLabels: [String],
                     outputs: PortValuesList,
                     outputLabels: [String],
                     activeIndex: ActiveIndex,
                     nodeType: NodeViewModelType,
                     parentGroupNodeId: NodeId?,
                     graphDelegate: GraphDelegate?) {
        var patchNodeEntity: PatchNodeEntity?
        var layerNodeEntity: LayerNodeEntity?
        var isGroup = false

        switch nodeType {
        case .patch(let patchNodeViewModel):
            patchNodeEntity = patchNodeViewModel.createSchema()
        case .layer(let layerNodeViewModel):
            layerNodeEntity = layerNodeViewModel.createSchema()
        case .group:
            isGroup = true
        }

        let inputEntities = inputs.enumerated().map { portId, values in
            NodePortInputEntity(id: NodeIOCoordinate(portId: portId,
                                                     nodeId: id),
                                nodeKind: nodeType.kind,
                                userVisibleType: patchNodeEntity?.userVisibleType,
                                values: values,
                                upstreamOutputCoordinate: nil)
        }

        let nodeEntity = NodeEntity(id: id,
                                    position: position.toCGPoint,
                                    zIndex: zIndex,
                                    parentGroupNodeId: parentGroupNodeId,
                                    patchNodeEntity: patchNodeEntity,
                                    layerNodeEntity: layerNodeEntity,
                                    isGroupNode: isGroup,
                                    title: customName ?? nodeType.kind.getDisplayTitle(customName: nil),
                                    inputs: inputEntities)

        self.init(from: nodeEntity,
                  activeIndex: activeIndex,
                  graphDelegate: graphDelegate)
        
        self.nodeType = nodeType
        self.patchNode?.outputsObservers = NodeRowObservers(values: outputs,
                                                            kind: self.kind,
                                                            userVisibleType: self.userVisibleType,
                                                            id: id,
                                                            nodeIO: .output,
                                                            activeIndex: activeIndex,
                                                            nodeDelegate: self)
    }
}

extension NodeViewModel: NodeCalculatable {
    @MainActor func getAllInputsObservers() -> [NodeRowObserver] {
        self.getRowObservers(.input)
    }
    
    @MainActor func getAllOutputsObservers() -> [NodeRowObserver] {
        self.getRowObservers(.output)
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
        self.updateOutputs(evalResult.outputsValues,
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
            (patchNode.inputsObservers + patchNode.outputsObservers).forEach {
                $0.userVisibleType = newType
            }
        }
    }
}

extension NodeViewModel {
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
    
    func getAllCanvasObservers() -> [CanvasNodeViewModel] {
        switch nodeType {
        case .patch(let patchNode):
            return [patchNode.canvasObserver]
        case .layer(let layerNode):
            return layerNode.getAllCanvasObservers()
        case .group(let canvasObserver):
            return [canvasObserver]
        }
    }
    
    /// Checks if any canvas entity for this node is visible.
    var isVisibleInFrame: Bool {
        for canvasObserver in self.getAllCanvasObservers() {
            if canvasObserver.isVisibleInFrame {
                return true
            }
        }
        
        return false
    }

    // Update both
    @MainActor
    func updateRowObservers(activeIndex: ActiveIndex) {
        // TODO: iterate over each row observer for each canvas....
        
        // Do nothing if not in frame
        guard self.isVisibleInFrame else {
            return
        }

        self.updateInputsObservers(newValuesList: self.inputs,
                                   activeIndex: activeIndex)
        self.updateOutputsObservers(newValuesList: self.outputs,
                                    activeIndex: activeIndex)
    }

    @MainActor
    func updateInputsObservers(newValuesList: PortValuesList,
                               activeIndex: ActiveIndex) {
        self.updateRowObservers(rowObservers: self.getRowObservers(.input),
                                newIOValues: newValuesList,
                                activeIndex: activeIndex)
    }

    @MainActor
    func updateOutputsObservers(newValuesList: PortValuesList,
                                activeIndex: ActiveIndex) {
        self.updateRowObservers(rowObservers: self.getRowObservers(.output),
                                newIOValues: newValuesList,
                                activeIndex: activeIndex)
    }

    @MainActor
    func getRowObservers(_ nodeIO: NodeIO) -> NodeRowObservers {
        guard self.kind != .group else {
            return self.graphDelegate?.getSplitterRowObservers(for: self.id,
                                                               type: nodeIO == .input ? .input : .output) ?? []
        }
        
        switch nodeIO {
        case .input:
            // Layers use key paths instead of array
            if let layerNode = self.layerNode {
                return layerNode.getSortedInputObservers()
            }
            return self.patchNode?.inputsObservers ?? []
        case .output:
            return self.patchNode?.outputsObservers ?? []
        }
    }
    
    @MainActor
    func getInputRowObserver(for portType: NodeIOPortType) -> NodeRowObserver? {
        switch portType {
        case .portIndex(let portId):
            // Assumes patch node for port ID
            return self.patchNode?.inputsObservers[safe: portId]

        case .keyPath(let keyPath):
            guard let layerNode = self.layerNode else {
                fatalErrorIfDebug()
                return nil
            }
            
            return layerNode[keyPath: keyPath.layerNodeKeyPath]
        }
    }

    @MainActor
    func getInputRowObserver(_ portId: Int) -> NodeRowObserver? {
        // Layers use key paths instead of array
        if let layerNode = self.layerNode {
            return layerNode.getSortedInputObservers()[safe: portId]
        }
        
        if kind == .group {
            return self.graphDelegate?
                .getSplitterRowObservers(for: self.id,
                                         type: .input)[safe: portId]
        }
        
        // Sometimes observers aren't yet created for nodes with adjustable inputs
        return self.patchNode?.inputsObservers[safe: portId]
    }
    
    @MainActor
    func getOutputRowObserver(for portType: NodeIOPortType) -> NodeRowObserver? {
        switch portType {
        case .keyPath:
            // No support here
            fatalErrorIfDebug()
            return nil
            
        case .portIndex(let portId):
            return self.getOutputRowObserver(portId)
        }
    }

    @MainActor
    func getOutputRowObserver(_ portId: Int) -> NodeRowObserver? {
        if kind == .group {
            return self.graphDelegate?
                .getSplitterRowObservers(for: self.id,
                                         type: .output)[safe: portId]
        }
        
        return self.patchNode?.outputsObservers[safe: portId]
    }

    @MainActor
    private func updateRowObservers(rowObservers: NodeRowObservers,
                                    newIOValues: PortValuesList,
                                    activeIndex: ActiveIndex) {

        newIOValues.enumerated().forEach { portId, newValues in
            guard let observer = rowObservers[safe: portId] else {
                #if DEV_DEBUG
                log("NodeViewModel.initializeThrottlers error: no observer found, this shouldn't happen.")
                log("NodeViewModel.initializeThrottlers: error: node.id: \(self.id)")
                log("NodeViewModel.initializeThrottlers: error: portId: \(portId)")
                #endif
                return
            }

            observer.updateValues(newValues,
                                  activeIndex: activeIndex,
                                  isVisibleInFrame: self.isVisibleInFrame)
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

    var displayTitle: String {
        guard self.id != Self.nilChoice.id else {
            return "None"
        }

        return self._cachedDisplayTitle
    }
    
    @MainActor
    func updateVisibilityStatus(with newValue: Bool,
                                activeIndex: ActiveIndex) {
        let oldValue = self.isVisibleInFrame
        if oldValue != newValue {
            self.isVisibleInFrame = newValue

            if self.kind == .group {
                // Group node needs to mark all input and output splitters as visible
                // Fixes issue for setting visibility on groups
                let inputsObservers = self.getRowObservers(.input)
                let outputsObservers = self.getRowObservers(.output)
                let allObservers = inputsObservers + outputsObservers
                allObservers.forEach {
                    $0.nodeDelegate?.isVisibleInFrame = newValue
                }
            }

            // Refresh values if node back in frame
            if newValue {
                self.updateRowObservers(activeIndex: activeIndex)
            }
        }
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
    var inputsRowCount: Int {
        self.getRowObservers(.input).count
    }
    
    var outputsRowCount: Int {
        self.getRowObservers(.output).count
    }
    
    var activeIndex: ActiveIndex {
        graphDelegate?.activeIndex ?? .init(.zero)
    }

    @MainActor
    func portCountShortened(to length: Int, nodeIO: NodeIO) {
        switch nodeIO {
        case .input:
            self.patchNode?.inputsObservers = Array(self.patchNode.inputsObservers[0..<length])
        case .output:
            self.patchNode?.outputsObservers = Array(self.patchNode.outputsObservers[0..<length])
        }
    }

    // TODO: where is this used? Why would an input be retrieving some other node from GraphState? Why not just grab from GraphState directly?
    func getNode(_ id: NodeId) -> NodeViewModel? {
        self.graphDelegate?.getNodeViewModel(id)
    }
    
    var getMathExpression: String? {
        self.patchNode?.mathExpression
    }
}


extension NodeViewModel: SchemaObserver {
    @MainActor
    static func createObject(from entity: NodeEntity) -> Self {
        return .init(from: entity,
                     activeIndex: .init(.zero),
                     graphDelegate: nil)
    }

    /// Wrapper function for easier discovery
    @MainActor
    func updateNodeViewModelFromSchema(_ nodeSchema: NodeEntity,
                                       activeIndex: ActiveIndex) {
        self.update(from: nodeSchema, activeIndex: activeIndex)
    }

    @MainActor
    func update(from schema: NodeEntity, 
                activeIndex: ActiveIndex) {
        self.update(from: schema)

        // Update view if no upstream connection
        // Layers use keypaths
        if let patchnode = self.patchNode {
            patchnode._getInputObserversForEncoding().forEach { inputObserver in
                if !inputObserver.upstreamOutputObserver.isDefined {
                    inputObserver.updateValues(
                        inputObserver.allLoopedValues,
                        activeIndex: activeIndex,
                        isVisibleInFrame: self.isVisibleInFrame)
                }
            }
        }
    }

    // MARK: main actor needed to prevent view updates from background thread
    @MainActor
    func update(from schema: NodeEntity) {
        self.nodeType.update(from: schema.nodeEntityType)

        if self.title != schema.title {
            self.title = schema.title
        }
        
        if self._cachedDisplayTitle != self.getDisplayTitle() {
            self._cachedDisplayTitle = self.getDisplayTitle()
        }
    }

    func createSchema() -> NodeEntity {
        NodeEntity(id: self.id,
                   nodeEntityType: self.nodeType.createSchema(),
                   title: self.title)
    }
    
    func onPrototypeRestart() {
        // Reset ephemeral observers
        self.createEphemeralObservers()
        
        // Reset outputs
        // TODO: should we really be resetting inputs?
        self._inputsObservers.onPrototypeRestart()
        self._outputsObservers.onPrototypeRestart()
        
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
            let newValue = observer.getActiveValue(activeIndex: activeIndex)
            observer.activeValueChanged(oldValue: oldValue, newValue: newValue)
        }

        self.getAllOutputsObservers().forEach { observer in
            let oldValue = observer.activeValue
            let newValue = observer.getActiveValue(activeIndex: activeIndex)
            observer.activeValueChanged(oldValue: oldValue, newValue: newValue)
        }
    }
    
    @MainActor
    var inputPortCount: Int {
        switch self.nodeType {
        case .layer(let layerNode):
            return layerNode.layer
                .layerGraphNode.inputDefinitions.count
        case .group:
            return self.graphDelegate?.getSplitterRowObservers(for: self.id,
                                                               type: .input).count ?? 0
        case .patch(let patchNode):
            return patchNode.inputsObservers.count
        }
    }
    
    @MainActor
    var outputPortCount: Int {
        switch kind {
        case .group:
            return self.graphDelegate?.getSplitterRowObservers(for: self.id,
                                                               type: .output).count ?? 0
        default:
            // Layers also use this
            return self.getAllOutputsObservers().count
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

        self.getAllOutputsObservers()[safe: portId]?
            .updateValues(values,
                          activeIndex: activeIndex,
                          isVisibleInFrame: self.isVisibleInFrame)
    }

    @MainActor
    func updateOutputs(_ newOutputsValues: PortValuesList,
                       activeIndex: ActiveIndex) {
        self.getAllOutputsObservers()
            .updateAllValues(newOutputsValues,
                             nodeIO: .output,
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
        let allInputsObservers = self.getRowObservers(.input)

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
        let newInputObserver = NodeRowObserver(values: lastRowObserver.allLoopedValues,
                                               nodeKind: self.kind,
                                               userVisibleType: self.userVisibleType,
                                               id: newInputCoordinate,
                                               activeIndex: self.activeIndex,
                                               upstreamOutputCoordinate: nil,
                                               nodeIOType: .input,
                                               nodeDelegate: lastRowObserver.nodeDelegate)
        
        patchNode.inputsObservers.append(newInputObserver)
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
    
    func appendInputRowObserver(_ rowObserver: NodeRowObserver) {
        guard let patchNode = self.patchNode else {
            fatalErrorIfDebug()
            return
        }
        
        patchNode.inputsObservers.append(rowObserver)
    }
}

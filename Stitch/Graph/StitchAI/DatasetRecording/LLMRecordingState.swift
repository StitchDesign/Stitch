//
//  LLMRecordingState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import StitchEngine


let LLM_COLLECTION_DIRECTORY = "StitchDataCollection"

enum LLMRecordingMode: Equatable {
    case normal
    case augmentation
}

enum LLMRecordingModal: Equatable, Hashable {
    // No active modal
    case none
    
    // Modal from which user can edit LLM Actions (remove those created by model or user; add new ones by interacting with the graph)
    case editBeforeSubmit
    
    // Modal from which either (1) re-enter LLM edit mode or (2) finally approve the LLM action list and send to Supabase
    case approveAndSubmit
}

struct LLMRecordingState {
    // Are we actively recording redux-actions which we then turn into LLM-actions?
    var isRecording: Bool = false
    
    // Track whether we've shown the modal in normal mode
    var hasShownModalInNormalMode: Bool = false
    
    // Do not create LLMActions while we are applying LLMActions
    var isApplyingActions: Bool = false
    
    // Error from validating or applying the LLM actions;
    // Note: we can actually have several, but only display one at a time
    var actionsError: String?
    
    var attempts: Int = 0
    
    static let maxAttempts: Int = 3
    
    var mode: LLMRecordingMode = .normal
    
    var actions: [Step] = .init()
    
    var promptState = LLMPromptState()
    
    var jsonEntryState = LLMJsonEntryState()
    
    var modal: LLMRecordingModal = .none
    
    // Tracks node positions, persisting across edits in case node is removed from validation failure
    var canvasItemPositions: [CanvasItemId : CGPoint] = .init()
    
    // Runs validation after every change
    var willAutoValidate = true
    
    // Tracks graph state before recording
    var initialGraphState: GraphEntity?
}

extension Array where Element == any StepActionable {
    func nodesCreatedByLLMActions() -> IdSet {
        let createdNodes = self.reduce(into: IdSet()) { partialResult, step in
            if let addNodeAction = step as? StepActionAddNode {
                partialResult.insert(addNodeAction.nodeId)
            }
        }
        log("nodesCreatedByLLMActions: createdNodes: \(createdNodes)")
        return createdNodes
    }
}

extension Array where Element == any StepActionable {
    /// Ensures newly created nodes won't overwrite the graph.
    func remapNodeIdsForNewNodes() -> Self {
        // Old : New pairings
        var idMap = [NodeId : NodeId]()
        
        self.forEach {
            if let addNodeAction = $0 as? StepActionAddNode {
                idMap.updateValue(.init(), forKey: addNodeAction.nodeId)
            }
        }
        
        let convertedIdSteps = self.map { step in
            step.remapNodeIds(nodeIdMap: idMap)
        }
        
        return convertedIdSteps
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func validateAndApplyActions(_ actions: [Step],
                                 isNewRequest: Bool = false) throws {
        // Wipe old error reason
        self.llmRecording.actionsError = nil
        
        var convertedActions = try actions
            .convertSteps()
        
        if isNewRequest {
            // Change Ids for newly created nodes
            convertedActions = convertedActions
                .remapNodeIdsForNewNodes()
        }
        
        // Are these steps valid?
        // invalid = e.g. tried to create a connection for a node before we created that node
        do {
            try convertedActions.validateLLMSteps()
        } catch let error as StitchAIManagerError {
            // immediately enter correction-mode: one of the actions, or perhaps the ordering, was incorrect
            self.llmRecording.actionsError = error.description
            self.startLLMAugmentationMode()
            log("validateAndApplyActions: hit error when validating LLM-actions: \(actions) ... error was: \(error)")
            throw error
        }
        
        for action in convertedActions {
            if let addAction = action as? StepActionAddNode {
                // add-node actions cannot re-use IDs
                assertInDebug(!self.visibleGraph.nodes.keys.contains(addAction.nodeId))
            }
            
            do {
                try self.applyAction(action)
            } catch let error as StitchFileError {
                self.llmRecording.actionsError = error.localizedDescription
                self.startLLMAugmentationMode()
                log("validateAndApplyActions: encountered error while trying to apply LLM-actions: \(error)")
                throw error
            }
        }
        
        // Only adjust node positions if actions were valid and successfully applied
        positionAIGeneratedNodes(convertedActions: convertedActions,
                                 nodes: self.visibleGraph.visibleNodesViewModel,
                                 viewPortCenter: self.newCanvasItemInsertionLocation)
        
        self.graphUpdaterId = .randomId() // NOT NEEDED, ACTUALLY?
    }
        
    @MainActor
    func deriveNewAIActions() -> [Step] {
        guard let oldGraphEntity = self.llmRecording.initialGraphState else {
            log("No graph state found")
            return []
        }
        
        let newGraphEntity = self.visibleGraph.createSchema()
        let oldNodeIds = oldGraphEntity.nodes.map(\.id).toSet
        let newNodeIds = newGraphEntity.nodes.map(\.id).toSet
        
        let nodeIdsToCreate = newNodeIds.subtracting(oldNodeIds)
        
        let newNodes: [NodeEntity] = nodeIdsToCreate.compactMap { newNodeId -> NodeEntity? in
            guard let nodeEntity = newGraphEntity.nodes.first(where: { $0.id == newNodeId }) else {
                fatalErrorIfDebug()
                return nil
            }
            
            return nodeEntity
        }
        
        var newNodesSteps: [StepActionAddNode] = []
        var newNodeTypesSteps: [StepActionChangeValueType] = []
        var newConnectionSteps: [StepActionConnectionAdded] = []
        var newSetInputSteps: [StepActionSetInput] = []
        
        // Create steps
        for nodeEntity in newNodes {
            guard let nodeName = PatchOrLayer.from(nodeKind: nodeEntity.kind) else {
                fatalErrorIfDebug()
                continue
            }
            
            let valueType = nodeEntity.nodeTypeEntity.patchNodeEntity?.userVisibleType
            let defaultValueType = nodeEntity.kind.getPatch?.defaultNodeType
            let stepAddNode = StepActionAddNode(nodeId: nodeEntity.id,
                                                nodeName: nodeName)
            newNodesSteps.append(stepAddNode)
            
            // Value type change if different from default
            if valueType != defaultValueType,
               let valueType = valueType {
                newNodeTypesSteps.append(.init(nodeId: nodeEntity.id,
                                               valueType: valueType))
            }
            
            // Create actions for values and connections
            switch nodeEntity.nodeTypeEntity {
            case .patch(let patchNode):
                let defaultInputs = nodeEntity.kind.defaultInputs(for: valueType)
                
                for (input, defaultInputValues) in zip(patchNode.inputs, defaultInputs) {
                    Self.deriveNewInputActions(input: input.portData,
                                               port: input.id,
                                               defaultInputs: defaultInputValues,
                                               newConnectionSteps: &newConnectionSteps,
                                               newSetInputSteps: &newSetInputSteps)
                }
                
            case .layer(let layerNode):
                for layerInput in layerNode.layer.layerGraphNode.inputDefinitions {
                    let port = NodeIOCoordinate(portType: .keyPath(.init(layerInput: layerInput,
                                                                         portType: .packed)),
                                                nodeId: nodeEntity.id)
                    let defaultInputValue = layerInput.getDefaultValue(for: layerNode.layer)
                    
                    let input = layerNode[keyPath: layerInput.schemaPortKeyPath].inputConnections.first!
                    Self.deriveNewInputActions(input: input,
                                               port: port,
                                               defaultInputs: [defaultInputValue],
                                               newConnectionSteps: &newConnectionSteps,
                                               newSetInputSteps: &newSetInputSteps)
                }
                
            default:
                continue
            }
        }
        
        // Sorting necessary for validation
        let newNodesStepsSorted = newNodesSteps
            .sorted { $0.nodeId < $1.nodeId }
            .map { $0.toStep }
        let newNodeTypesStepsSorted = newNodeTypesSteps
            .sorted { $0.nodeId < $1.nodeId }
            .map { $0.toStep }
        let newConnectionStepsSorted = newConnectionSteps
            .sorted { ($0.toPortCoordinate?.hashValue ?? 0) < ($1.toPortCoordinate?.hashValue ?? 0) }
            .map { $0.toStep }
        let newSetInputStepsSorted = newSetInputSteps
            .sorted { ($0.toPortCoordinate?.hashValue ?? 0) < ($1.toPortCoordinate?.hashValue ?? 0) }
            .map { $0.toStep }
        
        return newNodesStepsSorted +
        newNodeTypesStepsSorted +
        newConnectionStepsSorted +
        newSetInputStepsSorted
    }
    
    private static func deriveNewInputActions(input: NodeConnectionType,
                                              port: NodeIOCoordinate,
                                              defaultInputs: PortValues,
                                              newConnectionSteps: inout [StepActionConnectionAdded],
                                              newSetInputSteps: inout [StepActionSetInput]) {
        switch input {
        case .upstreamConnection(let upstreamConnection):
            let connectionStep: StepActionConnectionAdded = .init(port: port.portType,
                                                                  toNodeId: port.nodeId,
                                                                  fromPort: upstreamConnection.portId!,
                                                                  fromNodeId: upstreamConnection.nodeId)
            newConnectionSteps.append(connectionStep)
            
        case .values(let newInputs):
            if defaultInputs != newInputs {
                let value = newInputs.first!
                
                let setInputStep = StepActionSetInput(nodeId: port.nodeId,
                                                      port: port.portType,
                                                      value: value,
                                                      valueType: value.toNodeType)
                newSetInputSteps.append(setInputStep)
            }
        }
    }
    
    @MainActor
    func reapplyActions() throws {
        let oldActions = self.llmRecording.actions
        let actions = try self.llmRecording.actions.convertSteps()
        let graph = self.visibleGraph
        
        log("StitchDocumentViewModel: reapplyLLMActions: actions: \(actions)")
        // Save node positions
        self.llmRecording.canvasItemPositions = actions.reduce(into: [CanvasItemId : CGPoint]()) { result, action in
            if let action = action as? StepActionAddNode,
               let node = graph.getNode(action.nodeId) {
                let canvasItems = node.getAllCanvasObservers()

                canvasItems.forEach { canvasItem in
                    result.updateValue(canvasItem.position,
                                       forKey: canvasItem.id)
                }
            }
        }
        
        // Remove all actions before re-applying
        try self.llmRecording.actions
            .reversed()
            .forEach { action in
                let step = try action.convertToType()
                step.removeAction(graph: graph, document: self)
            }
        
        // Apply the LLM-actions (model-generated and user-augmented) to the graph
        try self.validateAndApplyActions(self.llmRecording.actions)
        
        // Update node positions to reflect previous position
        self.llmRecording.canvasItemPositions.forEach { canvasId, canvasPosition in
            if let canvas = graph.getCanvasItem(canvasId) {
                canvas.position = canvasPosition
                canvas.previousPosition = canvasPosition
            }
        }
        
        // Force update view
        self.graphUpdaterId = .randomId()
        
        // Validates that action data didn't change after derived actions is computed
        let newActions = self.llmRecording.actions
        try zip(oldActions, newActions).forEach { oldAction, newAction in
            if oldAction != newAction {
                throw StitchAIManagerError.actionValidationError("Found unequal actions:\n\(try oldAction.convertToType())\n\(try newAction.convertToType())")
            }
        }
    }
}

@MainActor
func positionAIGeneratedNodes(convertedActions: [any StepActionable],
                              nodes: VisibleNodesViewModel,
                              viewPortCenter: CGPoint) {
    
    let (depthMap, hasCycle) = convertedActions.calculateAINodesAdjacency()
    
    guard let depthMap = depthMap,
          !hasCycle else {
        fatalErrorIfDebug("Did not have a cycle but was not able create depth-map")
        return
    }
    
    guard !depthMap.isEmpty else {
//        fatalErrorIfDebug("Depth-map should never be empty")
        log("Depth-map should never be empty")
        return
    }
                    
    let depthLevels = depthMap.values.sorted().toOrderedSet

    let createdNodes = convertedActions.nodesCreatedByLLMActions()
        
    // Iterate by depth-level, so that nodes at same depth (e.g. 0) can be y-offset from each other
    depthLevels.forEach { depthLevel in

        // TODO: just rewrite the adjacency logic to be a mapping of [Int: [UUID]] instead of [UUID: Int]
        // Find all the created-nodes at this depth-level,
        // and adjust their positions
        let createdNodesAtThisLevel = createdNodes.compactMap {
            if depthMap.get($0) == depthLevel {
                return nodes.getNode($0)
            }
            log("positionAIGeneratedNodes: Could not get depth level for \($0.debugFriendlyId)")
            return nil
        }
        
        createdNodesAtThisLevel.enumerated().forEach { x in
            let createdNode = x.element
            let createdNodeIndexAtThisDepthLevel = x.offset
            // log("positionAIGeneratedNodes: createdNode.id: \(createdNode.id)")
            // log("positionAIGeneratedNodes: createdNodeIndexAtThisDepthLevel: \(createdNodeIndexAtThisDepthLevel)")
            createdNode.getAllCanvasObservers().enumerated().forEach { canvasItemAndIndex in
                let newPosition =  CGPoint(
                    x: viewPortCenter.x + (CGFloat(depthLevel) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_WIDTH_STAGGER),
                    y: viewPortCenter.y + (CGFloat(canvasItemAndIndex.offset) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER) + (CGFloat(createdNodeIndexAtThisDepthLevel) * CANVAS_ITEM_ADDED_VIA_LLM_STEP_HEIGHT_STAGGER)
                )
                // log("positionAIGeneratedNodes: canvasItemAndIndex.element.id: \(canvasItemAndIndex.element.id)")
                // log("positionAIGeneratedNodes: newPosition: \(newPosition)")
                canvasItemAndIndex.element.position = newPosition
                canvasItemAndIndex.element.previousPosition = newPosition
            }
        }
    }
}

// Might not need this anymore ?
// Also overlaps with `StitchAIPromptState` ?
struct LLMPromptState: Equatable {
    // can even show a long scrollable json of the encoded actions, so user can double check
    var showModal: Bool = false
    
    var prompt: String = ""
        
    // cached; updated when we open the prompt modal
    // TODO: find a better way to write the view such that the json's (of the encoded actions) keys are not shifting around as user types
    var actionsAsDisplayString: String = ""
}

// TODO: remove?
struct LLMJsonEntryState: Equatable {
    var showModal = false
    
    var jsonEntry: String = ""
    
    // Mapping of LLM node ids (e.g. "123456") to the id created
    // TODO: no longer needed, since LLM now provides real UUIDs which we use with the node?
    var llmNodeIdMapping = LLMNodeIdMapping()
}

typealias LLMNodeIdMapping = [String: NodeId]

//
//  PatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/28/21.
//

import Foundation
import StitchSchemaKit
import Combine
import CoreData
import RealityKit
import SwiftUI

typealias PatchNode = NodeViewModel
typealias NodeViewModels = [NodeViewModel]

@Observable
final class PatchNodeViewModel: Sendable {
    let id: NodeId
    
    // TODO: does this really need to be `@MainActor var` ? It's pure data (i.e. thread-independent) and should also be a `let` because can never change across the life 
    @MainActor var patch: Patch
    
    @MainActor
    var userVisibleType: UserVisibleType? {
        // TODO: can we simply update the node ephemeral observers' types when we change the userVisibleType itself ?
        didSet(oldValue) {
            if let oldValue = oldValue,
               let newValue = self.userVisibleType {
                dispatch(UpdateNodeEphemeralObserversUponNodeTypeChange(
                    id: self.id,
                    oldType: oldValue,
                    newType: newValue))
            }
        }
    }
    
    @MainActor var canvasObserver: CanvasItemViewModel
    
    // Used for data-intensive purposes (eval)
    @MainActor var inputsObservers: [InputNodeRowObserver] = []
    @MainActor var outputsObservers: [OutputNodeRowObserver] = []
    
    // Only for Math Expression nodes
    @MainActor var mathExpression: String?
    
    // Splitter types are for group input, output, or inline nodes
    @MainActor var splitterNode: SplitterNodeEntity?
    
    @MainActor var javaScriptNodeSettings: JavaScriptNodeSettings? = nil
    
    // Saves non-decoded result
    @MainActor var javaScriptDebugResult: String = ""
        
    @MainActor
    init(from schema: PatchNodeEntity) {
        let kind = NodeKind.patch(schema.patch)
        
        self.id = schema.id
        self.patch = schema.patch
        self.userVisibleType = schema.userVisibleType
        self.mathExpression = schema.mathExpression
        self.splitterNode = schema.splitterNode
        
        // Create initial inputs and outputs using default data
        let rowDefinitions = PatchOrLayer.patch(schema.patch)
            .rowDefinitionsOldOrNewStyle(for: schema.userVisibleType)
        
        // Must set inputs before calling eval below
        let inputsObservers = schema.inputs
            .createInputObservers(nodeId: schema.id,
                                  kind: kind,
                                  userVisibleType: schema.userVisibleType)

        let outputsObservers = rowDefinitions
            .createEmptyOutputObservers(nodeId: schema.id)
        
        self.canvasObserver = .init(from: schema.canvasEntity,
                                    id: .node(schema.id),
                                    inputRowObservers: inputsObservers,
                                    outputRowObservers: outputsObservers)
        
        self.inputsObservers = inputsObservers
        self.outputsObservers = outputsObservers
        
        // Setup JavaScript settings
        if let jsSettings = schema.javaScriptNodeSettings {
            log("PatchNodeViewModel: schema.javaScriptNodeSettings: \(jsSettings)")
            self.applyJavascriptToInputsAndOutputs(response: jsSettings,
                                                   currentGraphTime: self.documentDelegate?.graphStepState.graphTime ?? .zero,
                                                   activeIndex: self.documentDelegate?.activeIndex ?? .defaultActiveIndex)
        }
    }
}

extension PatchNodeViewModel: SchemaObserver {
    @MainActor
    var documentDelegate: StitchDocumentViewModel? {
        self.graphDelegate?.documentDelegate
    }
    
    @MainActor
    var graphDelegate: GraphState? {
        self.canvasObserver.nodeDelegate?.graphDelegate
    }
    
    @MainActor static func createObject(from entity: PatchNodeEntity) -> Self {
        self.init(from: entity)
    }

    @MainActor
    func update(from schema: PatchNodeEntity) {
        // Process JS settings before providing inputs
        if let newJsSettings = schema.javaScriptNodeSettings {
            log("PatchNodeViewModel: update: newJsSettings: \(newJsSettings)")
            self.applyJavascriptToInputsAndOutputs(response: newJsSettings,
                                                   currentGraphTime: self.documentDelegate?.graphStepState.graphTime ?? .zero,
                                                   activeIndex: self.documentDelegate?.activeIndex ?? .defaultActiveIndex)
        }
        
        self.inputsObservers.sync(with: schema.inputs)
        
        self.canvasObserver.update(from: schema.canvasEntity)
        
        assertInDebug(self.id == schema.id)
        
        if self.patch != schema.patch {
            self.patch = schema.patch
        }
        
        if self.userVisibleType != schema.userVisibleType {
            guard let oldType = self.userVisibleType,
                  let newType = schema.userVisibleType else {
                fatalErrorIfDebug("PatchNodeViewModel.update: expected node type when none found.")
                return
            }
            
            self.userVisibleType = newType
            
            if let graph = self.inputsObservers.first?.nodeDelegate?.graphDelegate,
               let node = graph.getNode(self.id) {
                let document = graph.documentDelegate
                
                // Ensures fields correctly update on events like undo which wouldn't otherwise
                // call the changeType helper
                let _ = graph.changeType(for: node,
                                         oldType: oldType,
                                         newType: newType,
                                         activeIndex: document?.activeIndex ?? .init(.zero),
                                         graphTime: document?.graphStepState.graphTime ?? .zero)
            }
        }
        
        if let oldSplitterNodeEntity = self.splitterNode,
           let newSplitterNodeEntity = schema.splitterNode,
           oldSplitterNodeEntity != newSplitterNodeEntity {
            self.splitterNode = newSplitterNodeEntity
        }
    }

    @MainActor
    func createSchema() -> PatchNodeEntity {
        PatchNodeEntity(id: self.id,
                        patch: self.patch,
                        inputs: self.inputsObservers.map { $0.createSchema() },
                        canvasEntity: self.canvasObserver.createSchema(),
                        userVisibleType: self.userVisibleType,
                        splitterNode: self.splitterNode,
                        mathExpression: self.mathExpression,
                        javaScriptNodeSettings: self.javaScriptNodeSettings)
    }
    
    func onPrototypeRestart(document: StitchDocumentViewModel) { }
}

extension PatchNodeViewModel {
    @MainActor
    func initializeDelegate(_ node: NodeViewModel,
                            graph: GraphState,
                            activeIndex: ActiveIndex) {
        
        self.inputsObservers.forEach {
            $0.assignNodeReferenceAndHandleValueChange(node, graph: graph)
        }
        
        self.outputsObservers.forEach {
            $0.assignNodeReferenceAndHandleValueChange(node, graph: graph)
        }
        
        self.canvasObserver.assignNodeReferenceAndUpdateFieldGroupsOnRowViewModels(
            node,
            activeIndex: activeIndex,
            unpackedPortParentFieldGroupType: nil,
            unpackedPortIndex: nil,
            graph: graph)
    }
    
    // Other inits better for public accesss
    @MainActor private convenience init(id: NodeId,
                                        patch: Patch,
                                        inputs: [NodePortInputEntity],
                                        canvasEntity: CanvasNodeEntity,
                                        userVisibleType: UserVisibleType? = nil,
                                        mathExpression: String?,
                                        splitterNode: SplitterNodeEntity?,
                                        activeIndex: ActiveIndex,
                                        delegate: NodeViewModel,
                                        graph: GraphState) {
        let entity = PatchNodeEntity(id: id,
                                     patch: patch,
                                     inputs: inputs,
                                     canvasEntity: canvasEntity,
                                     userVisibleType: userVisibleType,
                                     splitterNode: splitterNode,
                                     mathExpression: mathExpression,
                                     javaScriptNodeSettings: nil)
        self.init(from: entity)
        self.initializeDelegate(delegate, graph: graph, activeIndex: activeIndex)
        self.splitterNode = splitterNode
    }

    @MainActor convenience init(id: NodeId,
                                patch: Patch,
                                inputs: [NodePortInputEntity],
                                canvasEntity: CanvasNodeEntity,
                                userVisibleType: UserVisibleType? = nil,
                                activeIndex: ActiveIndex,
                                delegate: NodeViewModel,
                                graph: GraphState) {
        self.init(id: id,
                  patch: patch,
                  inputs: inputs,
                  canvasEntity: canvasEntity,
                  userVisibleType: userVisibleType,
                  mathExpression: nil,
                  splitterNode: nil,
                  activeIndex: activeIndex,
                  delegate: delegate,
                  graph: graph)
    }

    @MainActor
    var userTypeChoices: Set<UserVisibleType> {
        self.patch.availableNodeTypes
    }

    // Nodes like Core ML detection can have looped outputs without looped inputs.
    @MainActor
    var supportsOneToManyIO: Bool {
        self.patch.supportsOneToManyIO
    }

    @MainActor
    var splitterType: SplitterType? {
        get {
            self.splitterNode?.type
        }
        set(newValue) {
            guard let newValue = newValue else {
                self.splitterNode = nil
                return
            }

            self.splitterNode = SplitterNodeEntity(id: self.id,
                                                           lastModifiedDate: .init(),
                                                           type: newValue)
        }
    }
    
    @MainActor
    var parentGroupNodeId: NodeId? {
        get {
            self.canvasObserver.parentGroupNodeId
        }
        set(newValue) {
            self.canvasObserver.parentGroupNodeId = newValue
        }
    }
    
    @MainActor
    func updateMathExpressionNodeInputs(newExpression: String,
                                        node: NodeViewModel,
                                        activeIndex: ActiveIndex) {
        // Always set math-expr on node for its eval and (default) title
        if self.mathExpression != newExpression {
            self.mathExpression = newExpression            
        }
        
        // log("updateMathExpressionNodeInputs: newExpression: \(newExpression)")

        // Preserve order of presented characters;
        // Do not change upper- vs. lower-case etc.
        let variables = newExpression.getSoulverVariables()
        
        // log("updateMathExpressionNodeInputs: variables: \(variables)")
        
        let inputCountDelta = variables.count - self.inputsObservers.count
        var patchNodeSchema = self.createSchema()
        var inputSchemas = patchNodeSchema.inputs
        
        // Do nothing if input counts don't change
        guard inputCountDelta != 0 else {
            return
        }
        
        // Removing inputs scenario
        if inputCountDelta < 0 {
            inputSchemas = inputSchemas.dropLast(abs(inputCountDelta))
        }
        
        // Adding inputs scenario
        else if inputCountDelta > 0 {
            inputSchemas += (0..<inputCountDelta).map { index in
                let portId = variables.count + index - 1
                return NodePortInputEntity(id: .init(portId: portId, nodeId: node.id),
                                           portData: .values([.number(.zero)]))
            }
        }
        
        // Use schema to sync view models
        patchNodeSchema.inputs = inputSchemas
        self.update(from: patchNodeSchema)
        
        // Update input row view models in canvas
        self.canvasObserver
            .syncRowViewModels(with: self._inputsObservers,
                               keyPath: \.inputViewModels,
                               activeIndex: activeIndex)
    }
}

extension NodeViewModel {
    @MainActor
    convenience init(id: NodeId,
                     position: CGPoint = .zero,
                     zIndex: Double = .zero,
                     customName: String?,
                     inputs: PortValuesList,
                     inputLabels: [String],
                     outputs: PortValuesList,
                     outputLabels: [String],
                     patch: Patch,
                     userVisibleType: UserVisibleType?,
                     splitterNode: SplitterNodeEntity? = nil) {
        
        let inputEntities = inputs.enumerated().map { portId, values in
            NodePortInputEntity(id: NodeIOCoordinate(portId: portId,
                                                     nodeId: id),
                                portData: .values(values))
        }
            
        let canvasEntity = CanvasNodeEntity(position: position,
                                            zIndex: zIndex,
                                            parentGroupNodeId: nil)
        
        let patchNodeEntity = PatchNodeEntity(id: id,
                                              patch: patch,
                                              inputs: inputEntities,
                                              canvasEntity: canvasEntity,
                                              userVisibleType: userVisibleType,
                                              splitterNode: splitterNode,
                                              mathExpression: nil,
                                              javaScriptNodeSettings: nil)
        
        let nodeEntity = NodeEntity(id: id,
                                    nodeTypeEntity: .patch(patchNodeEntity),
                                    title: customName ?? NodeKind.patch(patch).getDisplayTitle(customName: nil))
        
        let patch = PatchNodeViewModel(from: patchNodeEntity)
        
        self.init(from: nodeEntity,
                  nodeType: .patch(patch))
    }
    
    @MainActor
    convenience init(position: CGPoint = .zero,
                     zIndex: Double = .zero,
                     id: NodeId,
                     patchName: Patch,
                     userVisibleType: UserVisibleType? = nil,
                     inputs: Inputs,
                     outputs: Outputs,
                     customName: String? = nil) {
        
        if patchName.availableNodeTypes.isEmpty,
            userVisibleType.isDefined {
                fatalErrorIfDebug("NodeViewModel legacy init: a patch node should never have a userVisibleType without any available node types; the non-nil userVisibleType is probably a mistake")
        }
        
        self.init(id: id,
                  position: position,
                  zIndex: zIndex,
                  customName: customName,
                  inputs: inputs.map { $0.values },
                  inputLabels: inputs.map { $0.label ?? "" },
                  outputs: outputs.map { $0.values },
                  outputLabels: outputs.map { $0.label ?? "" },
                  patch: patchName,
                  userVisibleType: userVisibleType)
    }
    
    @MainActor
    var patch: Patch? {
        self.kind.getPatch
    }
    
    // INTERNAL STATE, SPECIFIC TO A GIVEN PATCH NODE TYPE:
    
    // BETTER?: use an "internal state" struct
    @MainActor
    var queue: [PortValues] {
        self.computedStates?.compactMap { $0.queue } ?? []
    }
    
    @MainActor
    var smoothValueAnimationStates: [SmoothValueAnimationState]? {
        self.computedStates?.compactMap { $0.smoothValueAnimationState }
    }
    
    @MainActor
    var isWireless: Bool {
        patch == .wirelessBroadcaster || patch == .wirelessReceiver
    }
}

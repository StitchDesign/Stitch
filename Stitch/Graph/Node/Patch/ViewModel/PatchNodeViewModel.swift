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

// Legacy
typealias PatchNode = NodeViewModel
typealias NodeViewModels = [NodeViewModel]

protocol PatchNodeViewModelDelegate: NodeDelegate {
    @MainActor
    func userVisibleTypeChanged(oldType: UserVisibleType,
                                newType: UserVisibleType)
}

@Observable
final class PatchNodeViewModel: Sendable {
    let id: NodeId
    @MainActor var patch: Patch
    
    @MainActor
    var userVisibleType: UserVisibleType? {
        didSet(oldValue) {
            if let oldValue = oldValue,
               let newValue = self.userVisibleType {
                self.delegate?
                    .userVisibleTypeChanged(oldType: oldValue,
                                            newType: newValue)
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
    
    @MainActor weak var delegate: PatchNodeViewModelDelegate?
    
    @MainActor
    init(from schema: PatchNodeEntity) {
        let kind = NodeKind.patch(schema.patch)
        
        self.id = schema.id
        self.patch = schema.patch
        self.userVisibleType = schema.userVisibleType
        self.mathExpression = schema.mathExpression
        self.splitterNode = schema.splitterNode
        
        // Create initial inputs and outputs using default data
        let rowDefinitions = NodeKind.patch(schema.patch)
            .rowDefinitions(for: schema.userVisibleType)
        
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
                                    outputRowObservers: outputsObservers,
                                    unpackedPortParentFieldGroupType: nil,
                                    unpackedPortIndex: nil)
        
        self.inputsObservers = inputsObservers
        self.outputsObservers = outputsObservers
    }
}

extension PatchNodeViewModel: SchemaObserver {
    @MainActor static func createObject(from entity: PatchNodeEntity) -> Self {
        self.init(from: entity)
    }

    func update(from schema: PatchNodeEntity) {
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
            
            if let node = self.delegate,
               let graph = node.graphDelegate {
                // Ensures fields correctly update on events like undo which wouldn't otherwise
                // call the changeType helper
                let _ = graph.changeType(for: node,
                                         oldType: oldType,
                                         newType: newType,
                                         activeIndex: graph.documentDelegate?.activeIndex ?? .init(.zero))
            }
        }
        if let oldSplitterNodeEntity = self.splitterNode,
           let newSplitterNodeEntity = schema.splitterNode,
           oldSplitterNodeEntity != newSplitterNodeEntity {
            self.splitterNode = newSplitterNodeEntity
        }
    }

    func createSchema() -> PatchNodeEntity {
        PatchNodeEntity(id: self.id,
                        patch: self.patch,
                        inputs: self.inputsObservers.map { $0.createSchema() },
                        canvasEntity: self.canvasObserver.createSchema(),
                        userVisibleType: self.userVisibleType,
                        splitterNode: self.splitterNode,
                        mathExpression: self.mathExpression)
    }
    
    func onPrototypeRestart() { }
}

extension PatchNodeViewModel {
    @MainActor
    func initializeDelegate(_ node: PatchNodeViewModelDelegate) {
        self.delegate = node
        
        self.inputsObservers.forEach {
            $0.initializeDelegate(node)
        }
        
        self.outputsObservers.forEach {
            $0.initializeDelegate(node)
        }
        
        // Assign weak for group canvas if group splitter node
        
        self.canvasObserver.initializeDelegate(node,
                                               unpackedPortParentFieldGroupType: nil,
                                               unpackedPortIndex: nil)
    }
    
    // Other inits better for public accesss
    @MainActor private convenience init(id: NodeId,
                             patch: Patch,
                             inputs: [NodePortInputEntity],
                             canvasEntity: CanvasNodeEntity,
                             userVisibleType: UserVisibleType? = nil,
                             mathExpression: String?,
                             splitterNode: SplitterNodeEntity?,
                             delegate: PatchNodeViewModelDelegate) {
        let entity = PatchNodeEntity(id: id,
                                     patch: patch,
                                     inputs: inputs,
                                     canvasEntity: canvasEntity,
                                     userVisibleType: userVisibleType,
                                     splitterNode: splitterNode,
                                     mathExpression: mathExpression)
        self.init(from: entity)
        self.initializeDelegate(delegate)
        self.delegate = delegate
        self.splitterNode = splitterNode
    }

    @MainActor convenience init(id: NodeId,
                     patch: Patch,
                     inputs: [NodePortInputEntity],
                     canvasEntity: CanvasNodeEntity,
                     userVisibleType: UserVisibleType? = nil,
                     delegate: PatchNodeViewModelDelegate) {
        self.init(id: id,
                  patch: patch,
                  inputs: inputs,
                  canvasEntity: canvasEntity,
                  userVisibleType: userVisibleType,
                  mathExpression: nil,
                  splitterNode: nil,
                  delegate: delegate)
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
                                        node: NodeDelegate) {
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
                               // Not relevant
                               unpackedPortParentFieldGroupType: nil,
                               unpackedPortIndex: nil)
    }
}

extension NodeViewModel {
    @MainActor
    convenience init(id: NodeId,
                     position: CGSize = .zero,
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
            
        let canvasEntity = CanvasNodeEntity(position: position.toCGPoint,
                                            zIndex: zIndex,
                                            parentGroupNodeId: nil)
        
        let patchNodeEntity = PatchNodeEntity(id: id,
                                              patch: patch,
                                              inputs: inputEntities,
                                              canvasEntity: canvasEntity,
                                              userVisibleType: userVisibleType,
                                              splitterNode: splitterNode,
                                              mathExpression: nil)
        
        let nodeEntity = NodeEntity(id: id,
                                    nodeTypeEntity: .patch(patchNodeEntity),
                                    title: customName ?? NodeKind.patch(patch).getDisplayTitle(customName: nil))
        
        let patch = PatchNodeViewModel(from: patchNodeEntity)
        
        self.init(from: nodeEntity,
                  nodeType: .patch(patch))
    }
    
    @MainActor
    convenience init(position: CGSize = .zero,
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

extension Patch {
    /// Returns type choices in sorted order.
    /// **Note: this has potential perf cost if called too frequently in the view.**
    @MainActor
    static let nodeTypeChoices: [Patch: [NodeType]] = Self.allCases.reduce(into: [Patch : [NodeType]]()) { result, patch in
        let sortedChoices = Array(patch.availableNodeTypes)
            .sorted { n1, n2 in
                n1.display < n2.display
            }
        
        result.updateValue(sortedChoices, forKey: patch)
    }
}

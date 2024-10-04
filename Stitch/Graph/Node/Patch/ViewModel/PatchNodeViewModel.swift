//
//  PatchNode.swift
//  prototype
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
    func userVisibleTypeChanged(oldType: UserVisibleType,
                                newType: UserVisibleType)
}

@Observable
final class PatchNodeViewModel: Sendable {
    var id: NodeId
    var patch: Patch
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
    
    var canvasObserver: CanvasItemViewModel
    
    // Used for data-intensive purposes (eval)
    var inputsObservers: [InputNodeRowObserver] = []
    var outputsObservers: [OutputNodeRowObserver] = []
    
    // Only for Math Expression nodes
    var mathExpression: String?
    
    // Splitter types are for group input, output, or inline nodes
    var splitterNode: SplitterNodeEntity?
    
    weak var delegate: PatchNodeViewModelDelegate?
    
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
        let defaultOutputsList = rowDefinitions.outputs.defaultList
        
        // Must set inputs before calling eval below
        let inputsObservers = schema.inputs
            .createInputObservers(nodeId: schema.id,
                                  kind: kind,
                                  userVisibleType: schema.userVisibleType)

        let outputsObservers = rowDefinitions
            .createOutputObservers(nodeId: schema.id,
                                   values: defaultOutputsList,
                                   patch: schema.patch,
                                   userVisibleType: schema.userVisibleType)
        
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
        
        if self.id != schema.id {
            self.id = schema.id
        }
        if self.patch != schema.patch {
            self.patch = schema.patch
        }
        if self.userVisibleType != schema.userVisibleType {
            self.userVisibleType = schema.userVisibleType
        }
        if self.splitterNode != schema.splitterNode {
            self.splitterNode = schema.splitterNode
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
    func initializeDelegate(_ node: PatchNodeViewModelDelegate) {
        self.delegate = node
        
        self.inputsObservers.forEach {
            $0.initializeDelegate(node)
        }
        
        self.outputsObservers.forEach {
            $0.initializeDelegate(node)
        }
        
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
    
    /// Returns type choices in sorted order.
    /// **Note: this has potential perf cost if called too frequently in the view.**
    func getSortedUserTypeChoices() -> [UserVisibleType] {
        Array(self.patch.availableNodeTypes).sorted { n1, n2 in
            n1.display < n2.display
        }
    }

    var userTypeChoices: Set<UserVisibleType> {
        self.patch.availableNodeTypes
    }

    // Nodes like Core ML detection can have looped outputs without looped inputs.
    var supportsOneToManyIO: Bool {
        self.patch.supportsOneToManyIO
    }

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
        self.mathExpression = newExpression
        
        // log("updateMathExpressionNodeInputs: newExpression: \(newExpression)")

        // Preserve order of presented characters;
        // Do not change upper- vs. lower-case etc.
        let variables = newExpression.getSoulverVariables()
        
        // log("updateMathExpressionNodeInputs: variables: \(variables)")
        
        // Keep value and connection
        let oldInputs: [(PortValues, OutputCoordinate?)] = self.inputsObservers.map {
            ($0.allLoopedValues, $0.upstreamOutputCoordinate)
        }
        
        self._inputsObservers = variables.enumerated().map {
            let existingInput = oldInputs[safe: $0.offset]
            let inputObserver = InputNodeRowObserver(
                values: existingInput?.0 ?? [.number(.zero)],
                nodeKind: .patch(self.patch),
                userVisibleType: self.userVisibleType,
                id: InputCoordinate(portId: $0.offset,
                                    nodeId: self.id),
                upstreamOutputCoordinate: existingInput?.1)
            
            inputObserver.initializeDelegate(node)
            
            return inputObserver
        }
        
        // Update input row view models in canvas
        self.canvasObserver.inputViewModels.sync(with: self._inputsObservers,
                                                 canvas: self.canvasObserver,
                                                 // Not relevant
                                                 unpackedPortParentFieldGroupType: nil,
                                                 unpackedPortIndex: nil)
    }
    
    @MainActor
    func portCountShortened(to length: Int, nodeIO: NodeIO) {
        switch nodeIO {
        case .input:
            self.inputsObservers = Array(self.inputsObservers[0..<length])
        case .output:
            self.outputsObservers = Array(self.outputsObservers[0..<length])
        }
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
                                portData: .values(values),
                                nodeKind: .patch(patch),
                                userVisibleType: userVisibleType)
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
    
    var patch: Patch? {
        self.kind.getPatch
    }
    
    // INTERNAL STATE, SPECIFIC TO A GIVEN PATCH NODE TYPE:
    
    // BETTER?: use an "internal state" struct
    var queue: [PortValues] {
        self.computedStates?.compactMap { $0.queue } ?? []
    }
    
    var smoothValueAnimationStates: [SmoothValueAnimationState]? {
        self.computedStates?.compactMap { $0.smoothValueAnimationState }
    }
    
    var isWireless: Bool {
        patch == .wirelessBroadcaster || patch == .wirelessReceiver
    }
}

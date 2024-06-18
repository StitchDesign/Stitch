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
    
    let canvasObserver: CanvasNodeViewModel
    
    // Used for data-intensive purposes (eval)
    var inputsObservers: NodeRowObservers = []
    var outputsObservers: NodeRowObservers = []
    
    // Only for Math Expression nodes
    var mathExpression: String?
    
    // Splitter types are for group input, output, or inline nodes
    var splitterNode: SplitterNodeEntity?
    
    weak var delegate: PatchNodeViewModelDelegate?
    
    @MainActor init(from schema: PatchNodeEntity,
                    node: NodeDelegate?) {
        let kind = NodeKind.patch(schema.patch)
        
        self.id = schema.id
        self.patch = schema.patch
        self.userVisibleType = schema.userVisibleType
        self.mathExpression = schema.mathExpression
        self.splitterNode = schema.splitterNode

        self.canvasObserver = .init(from: schema.canvasEntity,
                                    node: node)
        
        // Create initial inputs and outputs using default data
        let rowDefinitions = NodeKind.patch(schema.patch)
            .rowDefinitions(for: schema.userVisibleType)
        let defaultOutputsList = rowDefinitions.outputs.defaultList
        
        // Must set inputs before calling eval below
        self.inputsObservers = schema.inputs
            .createInputObservers(nodeId: schema.id,
                                  kind: kind,
                                  userVisibleType: schema.userVisibleType,
                                  nodeDelegate: node)

        self.outputsObservers = rowDefinitions
            .createOutputObservers(nodeId: schema.id,
                                   values: defaultOutputsList,
                                   kind: kind,
                                   userVisibleType: schema.userVisibleType,
                                   nodeDelegate: node)
        
    }
}

extension PatchNodeViewModel: SchemaObserver {
    static func createObject(from entity: PatchNodeEntity) -> Self {
        self.init(from: entity,
                  node: nil)
    }

    func update(from schema: PatchNodeEntity) {
        self.inputsObservers.sync(with: schema.inputs)
        
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
    // Other inits better for public accesss
    @MainActor private convenience init(id: NodeId,
                             patch: Patch,
                             inputs: [NodePortInputEntity],
                             canvasEntity: CanvasNodeEntity,
                             userVisibleType: UserVisibleType? = nil,
                             mathExpression: String?,
                             splitterNode: SplitterNodeEntity?,
                             delegate: PatchNodeViewModelDelegate?) {
        let entity = PatchNodeEntity(id: id,
                                     patch: patch,
                                     inputs: inputs,
                                     canvasEntity: canvasEntity,
                                     userVisibleType: userVisibleType,
                                     splitterNode: splitterNode,
                                     mathExpression: mathExpression)
        self.init(from: entity,
                  node: delegate)
        self.delegate = delegate
        self.splitterNode = splitterNode
    }

    @MainActor convenience init(id: NodeId,
                     patch: Patch,
                     inputs: [NodePortInputEntity],
                     canvasEntity: CanvasNodeEntity,
                     userVisibleType: UserVisibleType? = nil,
                     delegate: PatchNodeViewModelDelegate?) {
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
            n1.rawValue < n2.rawValue
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
    
    /// Used for encoding step to get non-computed input row observers. Not intended for graph computation.
    func _getInputObserversForEncoding() -> NodeRowObservers {
        self._inputsObservers
    }
    
    @MainActor
    func updateMathExpressionNodeInputs(newExpression: String) {
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
            return NodeRowObserver(
                values: existingInput?.0 ?? [.number(.zero)],
                nodeKind: .patch(self.patch),
                userVisibleType: self.userVisibleType,
                id: InputCoordinate(portId: $0.offset,
                                    nodeId: self.id),
                activeIndex: self.delegate?.activeIndex ?? .init(.zero),
                upstreamOutputCoordinate: existingInput?.1,
                nodeIOType: .input,
                nodeDelegate: self.delegate)
        }
        
        // Update cached port view data
        self.updateAllPortViewData()
    }
    
    /// Updates UI IDs for each row observer. This is data that's only used for views and has costly perf.
    @MainActor
    func updateAllPortViewData() {
        self.inputsObservers.forEach { $0.updatePortViewData() }
        self.outputsObservers.forEach { $0.updatePortViewData() }
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
                     activeIndex: ActiveIndex,
                     patch: Patch,
                     userVisibleType: UserVisibleType?,
                     splitterNode: SplitterNodeEntity? = nil) {
        
        let inputEntities = inputs.enumerated().map { portId, values in
            NodePortInputEntity(id: NodeIOCoordinate(portId: portId,
                                                     nodeId: id),
                                nodeKind: nodeType.kind,
                                userVisibleType: userVisibleType,
                                values: values,
                                upstreamOutputCoordinate: nil)
        }
            
        let canvasEntity = CanvasNodeEntity(id: .init(),
                                            position: position.toCGPoint,
                                            zIndex: zIndex,
                                            parentGroupNodeId: nil)

        let patchNode = PatchNodeViewModel(
            id: id,
            patch: patch,
            inputs: inputEntities,
            canvasEntity: canvasEntity,
            userVisibleType: userVisibleType,
            delegate: nil)

        self.init(id: id,
                  position: position,
                  zIndex: zIndex,
                  customName: customName ?? patch.defaultDisplayTitle(),
                  inputs: inputs,
                  inputLabels: inputLabels,
                  outputs: outputs,
                  outputLabels: outputLabels,
                  activeIndex: activeIndex,
                  nodeType: .patch(patchNode),
                  parentGroupNodeId: nil,
                  graphDelegate: nil)

        patchNode.delegate = self
        patchNode.canvasObserver.nodeDelegate = self

        // Set splitter info
        patchNode.splitterNode = splitterNode
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
                  activeIndex: .init(.zero),
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

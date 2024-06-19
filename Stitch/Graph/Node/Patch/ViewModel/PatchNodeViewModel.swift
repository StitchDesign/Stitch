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
    
    let canvasObserver: NodeCanvasViewModel
    
    // Used for data-intensive purposes (eval)
    var inputsObservers: NodeRowObservers = []
    var outputsObservers: NodeRowObservers = []
    
    // Only for Math Expression nodes
    var mathExpression: String?
    
    // Splitter types are for group input, output, or inline nodes
    var splitterNode: SplitterNodeEntity?
    
    weak var delegate: PatchNodeViewModelDelegate?
    
    init(from schema: PatchNodeEntity) {
        self.id = schema.id
        self.patch = schema.patch
        self.userVisibleType = schema.userVisibleType
        self.mathExpression = schema.mathExpression
        self.splitterNode = schema.splitterNode
        
        // TODO: build canvas and input/output data
        fatalError()

        //        self.canvasObserver = ...
        
        // MARK: this is the exact code that was in NodeViewModel init
//        // Must set inputs before calling eval below
//        self._inputsObservers = schema.inputs
//            .createInputObservers(nodeId: schema.id,
//                                  kind: self.kind,
//                                  userVisibleType: schema.patchNodeEntity?.userVisibleType,
//                                  nodeDelegate: self)
//
//        self._outputsObservers = rowDefinitions
//            .createOutputObservers(nodeId: schema.id,
//                                   values: self.defaultOutputsList,
//                                   nodeDelegate: self)
        
    }
}

extension PatchNodeViewModel: SchemaObserver {
    static func createObject(from entity: PatchNodeEntity) -> Self {
        // TODO: patch needs canvas entity
        fatalError()
        
        self.init(from: entity)
    }

    func update(from schema: PatchNodeEntity) {
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
                        userVisibleType: self.userVisibleType,
                        splitterNode: self.splitterNode, 
                        mathExpression: self.mathExpression)
    }
    
    func onPrototypeRestart() { }
}

extension PatchNodeViewModel {
    // Other inits better for public accesss
    private convenience init(id: NodeId,
                             patch: Patch,
                             userVisibleType: UserVisibleType? = nil,
                             mathExpression: String?,
                             splitterNode: SplitterNodeEntity?,
                             delegate: PatchNodeViewModelDelegate?) {
        let entity = PatchNodeEntity(id: id,
                                     patch: patch,
                                     userVisibleType: userVisibleType,
                                     splitterNode: splitterNode,
                                     mathExpression: mathExpression)
        self.init(from: entity)
        self.delegate = delegate
        self.splitterNode = splitterNode
    }

    convenience init(id: NodeId,
                     patch: Patch,
                     userVisibleType: UserVisibleType? = nil,
                     delegate: PatchNodeViewModelDelegate?) {
        self.init(id: id,
                  patch: patch,
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
        let oldInputs: [(PortValues, OutputCoordinate?)] = self.getRowObservers(.input).map {
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

        let patchNode = PatchNodeViewModel(
            id: id,
            patch: patch,
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

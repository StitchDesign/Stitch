//
//  NodeDelegate.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit

/*
 Properties on the NODE that we might need in an Input or Output.
 
 We could pass in the entire Node, but this is a more specific dep-type that only gives us what we want.

 Used only by NodeViewModel.
 */
protocol NodeDelegate: AnyObject {
    var id: NodeId { get }
    
    var kind: NodeKind { get }
    
    var userVisibleType: UserVisibleType? { get }
    
    var nodeType: NodeViewModelType { get }
    
    @MainActor var allInputViewModels: [InputNodeRowViewModel] { get }
    
    @MainActor var allOutputViewModels: [OutputNodeRowViewModel] { get }
    
    @MainActor var longestLoopLength: Int { get }

    @MainActor var inputsRowCount: Int { get }
    
    @MainActor var outputsRowCount: Int { get }
    
    var activeIndex: ActiveIndex { get }
    
    @MainActor var displayTitle: String { get }

    @MainActor var inputs: PortValuesList { get }
    
    @MainActor var outputs: PortValuesList { get }
    
    var graphDelegate: GraphDelegate? { get }
    
    var splitterType: SplitterType? { get }
    
    var ephemeralObservers: [any NodeEphemeralObservable]? { get }
    
    // TODO: why is this a function? is it the id of the node represented by the `NodeObserverDelegate`, or is it actually an accessor on GraphState?
    @MainActor func getNode(_ id: NodeId) -> NodeViewModel?
        
    var getMathExpression: String? { get }
    
    @MainActor func getAllCanvasObservers() -> [CanvasItemViewModel]
    
    @MainActor func getInputRowObserver(for portType: NodeIOPortType) -> InputNodeRowObserver?
    
    @MainActor func getInputRowObserver(_ portId: Int) -> InputNodeRowObserver?
    
    @MainActor func getOutputRowObserver(_ portId: Int) -> OutputNodeRowObserver?
    
    @MainActor func getAllInputsObservers() -> [InputNodeRowObserver]
    
    @MainActor func getAllOutputsObservers() -> [OutputNodeRowObserver]
    
    @MainActor func updateInputPortViewModels(activeIndex: ActiveIndex)
    
    @MainActor func updateOutputPortViewModels(activeIndex: ActiveIndex)
        
    @MainActor func calculate()
}

extension NodeDelegate {
    var defaultOutputs: PortValues {
        guard let values = self.kind.graphNode?.rowDefinitions(for: self.userVisibleType).outputs
            .map({ $0.value }),
              !values.isEmpty else {
            return []
        }
        
        return values
    }
    
    var defaultOutputsList: PortValuesList {
        self.defaultOutputs.map { [$0] }
    }
    
    /// Similar to `getAllInputsObservers` but gets unpacked layer observers if used.
    @MainActor func getAllInputsObservers() -> [InputNodeRowObserver] {
        switch self.nodeType {
        case .patch(let patch):
            return patch.inputsObservers
        case .layer(let layer):
            return layer.getSortedInputPorts().flatMap { portObserver in
                // Grabs packed or unpacked data depending on what's used
                portObserver.allInputData.map { $0.rowObserver }
            }
        case .group(let canvas):
            return canvas.inputViewModels.compactMap {
                $0.rowDelegate
            }
        case .component(let component):
            return component.canvas.inputViewModels.compactMap {
                $0.rowDelegate
            }
        }
    }
    
    @MainActor
    var allInputRowViewModels: [InputNodeRowViewModel] {
        self.getAllInputsObservers()
            .flatMap { $0.allRowViewModels }
    }
    
    @MainActor
    var allNodeInputRowViewModels: [InputNodeRowViewModel] {
        self.allInputRowViewModels
            .filter { $0.id.isNode }
    }
    
    @MainActor
    var allOutputRowViewModels: [OutputNodeRowViewModel] {
        self.getAllOutputsObservers()
            .flatMap { $0.allRowViewModels }
    }
    
    @MainActor var patchNodeViewModel: PatchNodeViewModel? {
        switch self.nodeType {
        case .patch(let patchNode):
            return patchNode
        default:
            return nil
        }
    }
    
    var layerNodeViewModel: LayerNodeViewModel? {
        switch self.nodeType {
        case .layer(let layerNode):
            return layerNode
        default:
            return nil
        }
    }
}

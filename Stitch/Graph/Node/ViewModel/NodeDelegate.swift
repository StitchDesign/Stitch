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
    
//    var isVisibleInFrame: Bool { get set }
    
    var kind: NodeKind { get }
    
    var userVisibleType: UserVisibleType? { get }
    
//    var parentGroupNodeId: NodeId? { get }
    
    var patchNodeViewModel: PatchNodeViewModel? { get }
    
    @MainActor var longestLoopLength: Int { get }

    @MainActor var inputsRowCount: Int { get }
    
    @MainActor var outputsRowCount: Int { get }
    
    @MainActor var activeIndex: ActiveIndex { get }
    
//    @MainActor var isNodeMoving: Bool { get }
    
//    @MainActor var isSelected: Bool { get set }
    
    @MainActor var inputs: PortValuesList { get }
    
    @MainActor var outputs: PortValuesList { get }
    
    var graphDelegate: GraphDelegate? { get }
    
    var splitterType: SplitterType? { get }
    
    var ephemeralObservers: [any NodeEphemeralObservable]? { get }
    
    @MainActor func portCountShortened(to length: Int, nodeIO: NodeIO)
    
    // TODO: why is this a function? is it the id of the node represented by the `NodeObserverDelegate`, or is it actually an accessor on GraphState?
    @MainActor func getNode(_ id: NodeId) -> NodeViewModel?
        
    var getMathExpression: String? { get }
    
    @MainActor func getAllCanvasObservers() -> [CanvasItemViewModel]
    
    @MainActor func getInputRowObserver(for portType: NodeIOPortType) -> InputNodeRowObserver?
    
    @MainActor func getInputRowObserver(_ portId: Int) -> InputNodeRowObserver?
    
    @MainActor func getOutputRowObserver(_ portId: Int) -> OutputNodeRowObserver?
    
    @MainActor func getAllInputsObservers() -> [InputNodeRowObserver]
    
    @MainActor func getAllOutputsObservers() -> [OutputNodeRowObserver]
    
//    @MainActor func updateRowObservers(activeIndex: ActiveIndex)
    
    @MainActor func nextInput(_ currentInputCoordinate: NodeIOPortType) -> FieldCoordinate
    
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
    
    @MainActor
    var allInputRowViewModels: [InputNodeRowViewModel] {
        self.getAllInputsObservers()
            .map { $0.rowViewModel }
    }
    
    @MainActor
    var allOutputRowViewModels: [OutputNodeRowViewModel] {
        self.getAllOutputsObservers()
            .map { $0.rowViewModel }
    }
}

//
//  NodeViewModelUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/24.
//

import Foundation
import StitchSchemaKit

extension NodeViewModel {
    @MainActor
    convenience init<T: NodeDefinition>(from graphNode: T.Type,
                                        id: NodeId = NodeId(),
                                        position: CGPoint = .zero,
                                        zIndex: CGFloat = .zero,
                                        parentGroupNodeId: GroupNodeId? = nil,
                                        activeIndex: ActiveIndex,
                                        graphDelegate: GraphDelegate?) {
        var nodeType: NodeTypeEntity
        let kind = T.graphKind.kind
        let userVisibleType = kind.graphNode?.graphKind.patch?.defaultUserVisibleType
        
        let defaultInputs = kind.rowDefinitions(for: userVisibleType).inputs
            .enumerated()
            .map { portId, inputData in
                var coordinate: NodeIOCoordinate
                if let layerInput = inputData.layerInputType {
                    coordinate = .init(portType: .keyPath(layerInput),
                                       nodeId: id)
                } else {
                    coordinate = .init(portId: portId, nodeId: id)
                }
                
                return NodePortInputEntity(id: coordinate,
                                           portData: .values(inputData.defaultValues),
                                           nodeKind: kind,
                                           userVisibleType: userVisibleType)
            }
        
        let canvasEntity = CanvasNodeEntity(position: position,
                                            zIndex: zIndex,
                                            parentGroupNodeId: parentGroupNodeId?.asNodeId)

        switch T.graphKind {
        case .patch(let patchNode):
            let splitter: SplitterNodeEntity? = patchNode.patch == .splitter ? .init(id: id,
                                                                                     lastModifiedDate: Date.now,
                                                                                     type: .inline) : nil

            let patchNode = PatchNodeEntity(
                id: id,
                patch: patchNode.patch,
                inputs: defaultInputs,
                canvasEntity: canvasEntity,
                userVisibleType: patchNode.defaultUserVisibleType,
                splitterNode: splitter,
                mathExpression: patchNode.patch == .mathExpression ? "" : nil)
            nodeType = .patch(patchNode)

        case .layer(let layerNode):
            let layerNode = LayerNodeEntity(nodeId: id,
                                            layer: layerNode.layer,
                                            hasSidebarVisibility: true,
                                            layerGroupId: nil,
                                            isExpandedInSidebar: nil)
            
            nodeType = .layer(layerNode)
        }

        let nodeEntity = NodeEntity(id: id,
                                    nodeTypeEntity: nodeType,
                                    title: graphNode.defaultTitle)
        self.init(from: nodeEntity,
                  activeIndex: activeIndex,
                  graphDelegate: graphDelegate)
    }

    var userVisibleType: UserVisibleType? {
        get {
            self.nodeType.patchNode?.userVisibleType
        }
        set(newValue) {
            guard let patchNode = self.nodeType.patchNode else {
                return
            }

            patchNode.userVisibleType = newValue
        }
    }

    var splitterType: SplitterType? {
        get {
            self.nodeType.patchNode?.splitterType
        }
        set(newValue) {
            guard let patchNode = self.nodeType.patchNode else {
                return
            }

            patchNode.splitterType = newValue
        }
    }

    var kind: NodeKind {
        self.nodeType.kind
    }

    @MainActor
    var currentBroadcastChoiceId: NodeId? {
        self.getInputRowObserver(0)?.currentBroadcastChoiceId
    }

    @MainActor
    static var mock: NodeViewModel {
        NodeViewModel(from: SplitterPatchNode.self,
                      activeIndex: .init(.zero),
                      graphDelegate: nil)
    }

    @MainActor
    var inputs: PortValuesList {
        self.getAllInputsObservers().map { $0.allLoopedValues }
    }

    @MainActor
    var outputs: PortValuesList {
        self.getAllOutputsObservers().map { $0.allLoopedValues }
    }
    
    @MainActor
    func allRowObservers() -> [any NodeRowObserver] {
        self.getAllInputsObservers() + self.getAllOutputsObservers()
    }
    
//    @MainActor
//    func getAllViewInputPorts() -> [InputPortViewData] {
//        (0..<self.inputPortCount).map {
//            .init(portId: $0, nodeId: self.id)
//        }
//    }
    
//    @MainActor
//    func getAllViewOutputPorts() -> [OutputPortViewData] {
//        (0..<self.outputPortCount).map {
//            .init(portId: $0, nodeId: self.id)
//        }
//    }
    
    /*
     Used only for node type changes, i.e. changing the type of existing inputs.

     1. Sets new type on node
     2. updates each input on node to use new type

     Note: we do not need to update outputs' types -- those will be fixed by running the node's eval.
     Note 2: we can ignore NodeRowOberser.userVisibleType, at least on outputs.
     
     FKA `coerceAllValues`
     */
    @MainActor
    func updateNodeTypeAndInputs(newType: UserVisibleType,
                                 currentGraphTime: TimeInterval,
                                 activeIndex: ActiveIndex) {

        self.userVisibleType = newType
        
        self.getAllInputsObservers().enumerated().forEach { index, inputObserver in
            inputObserver.changeInputType(
                to: newType,
                nodeKind: self.kind,
                currentGraphTime: currentGraphTime,
                computedState: self.computedStates?[safe: index],
                activeIndex: activeIndex,
                isVisible: self.isVisibleInFrame)
        }
    }
    
//    /// Updates UI IDs for each row observer. This is data that's only used for views and has costly perf.
//    @MainActor
//    func updateAllPortViewData() {
//        let inputsObservers = self.getAllInputsObservers()
//        let outputsObservers = self.getAllOutputsObservers()
//        
//        inputsObservers.forEach { $0.updatePortViewData() }
//        outputsObservers.forEach { $0.updatePortViewData() }
//    }
    
    @MainActor
    func updateAllConnectedNodes() {
        let inputsObservers = self.getAllInputsObservers()
        let outputsObservers = self.getAllOutputsObservers()
        
        inputsObservers.forEach { $0.rowViewModel.updateConnectedCanvasItems() }
        outputsObservers.forEach { $0.rowViewModel.updateConnectedCanvasItems() }
    }
    
    /// Helper to update value at some specific port and loop.
    @MainActor
    func updateValue(_ value: PortValue,
                     nodeIO: NodeIO,
                     port: Int,
                     loop: Int,
                     activeIndex: ActiveIndex,
                     isVisibleInFrame: Bool) {
        guard let observer = self.getRowObservers(nodeIO)[safe: port],
              let oldValue = observer.allLoopedValues[safe: loop] else {
            #if DEBUG
            fatalError()
            #endif
            return
        }

        if oldValue != value {
            var newValues = observer.allLoopedValues
            guard loop < newValues.count else {
                #if DEBUG
                fatalError()
                #endif
                return
            }

            newValues[port] = value
            observer.updateValues(newValues,
                                  activeIndex: activeIndex,
                                  isVisibleInFrame: isVisibleInFrame)
        }
    }
    
    // MARK: heavy perf cost due to human readable strings.**
    func getDisplayTitle() -> String {
        // always prefer a custom name
        self.kind.getDisplayTitle(customName: self.title)
    }
    
    var layerNodeId: LayerNodeId {
        LayerNodeId(self.id)
    }

    var isGroupLayer: Bool {
        self.kind.getLayer == .group
    }

    static let nodeUIKind: NodeUIKind = NodeUIKind.inputsOnly
    
    @MainActor
    func inputCoordinate(at portId: Int) -> InputCoordinate? {
        portId > self.inputs.count
            ? nil
            : InputCoordinate(portId: portId, nodeId: self.id)
    }

    @MainActor
    func outputCoordinate(at portId: Int) -> OutputCoordinate? {
        portId > self.outputs.count
            ? nil
            : OutputCoordinate(portId: portId, nodeId: self.id)
    }

    @MainActor
    func getPatchLoopIndices() -> [Int] {
        (self as NodeViewModel).getLoopIndices()
    }

    var patchNode: PatchNodeViewModel? {
        nodeType.patchNode
    }

    var layerNode: LayerNodeViewModel? {
        nodeType.layerNode
    }

    @MainActor
    func getAsyncMediaOutputs(loopIndex: Int) -> AsyncMediaOutputs? {

        // MUST USE LENGTHENED OUTPUTS
        let lengthenedOutputs = self.outputsLengthenedByLongestInputLoop

        if self.patchNode?.supportsOneToManyIO ?? false {
            return .all(lengthenedOutputs)
        } else {
            let remappedOutputs = lengthenedOutputs.remapOutputs()
            guard let outputsAtIndex = remappedOutputs[safe: loopIndex] else {
                return nil
            }
            return .byIndex(outputsAtIndex)
        }
    }

    @MainActor
    var outputsLengthenedByLongestInputLoop: PortValuesList {
        getLengthenedArrays(self.outputs,
                            longestLoopLength: getLongestLoopLength(self.inputs))
    }
    
    func shiftPosition(by gridLineLength: Int = SQUARE_SIDE_LENGTH) {
        let gridLineLength = CGFloat(gridLineLength)
        
        self.position = .init(
            x: self.position.x + gridLineLength,
            y: self.position.y + gridLineLength)
        
        self.previousPosition = self.position
    }
    
    @MainActor
    var outputCoordinates: NodeIOCoordinates {
        (
            0..<self.outputs.count
        )
        .map {
            .init(portId: $0, nodeId: self.id)
        }
    }
}

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
                                        graphDelegate: GraphState?) {
        let kind = T.graphKind.kind
        let userVisibleType = kind.graphNode?.graphKind.patch?.defaultUserVisibleType
        
        let defaultInputs = kind.rowDefinitions(for: userVisibleType).inputs
            .enumerated()
            .map { portId, inputData in
                var coordinate: NodeIOCoordinate
                if let layerInput = inputData.layerInputType {
                    coordinate = .init(portType: .keyPath(.init(layerInput: layerInput,
                                                                portType: .packed)),
                                       nodeId: id)
                } else {
                    coordinate = .init(portId: portId, nodeId: id)
                }
                
                return NodePortInputEntity(id: coordinate,
                                           portData: .values(inputData.defaultValues))
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
            
            let nodeEntity = NodeEntity(id: id,
                                        nodeTypeEntity: .patch(patchNode),
                                        title: graphNode.defaultTitle)
            let patchNodeViewModel = PatchNodeViewModel(from: patchNode)
            
            self.init(from: nodeEntity,
                      nodeType: .patch(patchNodeViewModel))
            

        case .layer(let layerNode):
            let layerNode = LayerNodeEntity(nodeId: id,
                                            layer: layerNode.layer,
                                            hasSidebarVisibility: true,
                                            layerGroupId: nil)
            let nodeEntity = NodeEntity(id: id,
                                        nodeTypeEntity: .layer(layerNode),
                                        title: graphNode.defaultTitle)
            let layerNodeViewModel = LayerNodeViewModel(from: layerNode)
            
            self.init(from: nodeEntity,
                      nodeType: .layer(layerNodeViewModel))
        }
        
        if let graphDelegate = graphDelegate,
           let document = graphDelegate.documentDelegate {
            self.initializeDelegate(graph: graphDelegate,
                                    document: document)
        }
    }

    @MainActor
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

    @MainActor
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
    
    @MainActor
    var currentBroadcastChoiceId: NodeId? {
        
        guard self.kind == .patch(.wirelessReceiver) else {
            return nil
        }
              
        guard let firstInput = self.getInputRowObserver(0) else {
            fatalErrorIfDebug()
            return nil
        }
    
        // the id of the connected wireless broadcast node
        // TODO: why was there an `upstreamOutputCoordinate` but not a `upstreamOutputObserver` ?
        let wirelessBroadcastId = firstInput.upstreamOutputCoordinate?.nodeId
        // log("NodeRowObserver: currentBroadcastChoice: wirelessBroadcastId: \(wirelessBroadcastId)")
        return wirelessBroadcastId
    }

    @MainActor
    static var mock: NodeViewModel {
        NodeViewModel(from: SplitterPatchNode.self,
                      graphDelegate: nil)
    }

    @MainActor
    var inputs: PortValuesList {
        self.inputsValuesList
    }

    @MainActor
    var outputs: PortValuesList {
        self.getAllOutputsObservers().map { $0.allLoopedValues }
    }

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
                                 activeIndex: ActiveIndex,
                                 graph: GraphState) {

        self.userVisibleType = newType
        
        self.getAllInputsObservers().enumerated().forEach { index, inputObserver in
            inputObserver.changeInputType(
                to: newType,
                nodeKind: self.kind,
                currentGraphTime: currentGraphTime,
                computedState: self.computedStates?[safe: index],
                activeIndex: activeIndex,
                isVisible: self.isVisibleInFrame(graph.visibleCanvasIds, graph.selectedSidebarLayers))
        }
    }
    
    @MainActor func updateObserversPortColorsAndConnectedItemsPortColors(selectedEdges: Set<PortEdgeUI>,
                                                                                 drawingObserver: EdgeDrawingObserver) {
        self.inputsObservers.forEach {
            $0.updatePortColorAndUpstreamOutputPortColor(selectedEdges: selectedEdges,
                                                         drawingObserver: drawingObserver)
        }
        self.outputsObservers.forEach {
            $0.updatePortColorAndDownstreamInputsPortColors(selectedEdges: selectedEdges,
                                                            drawingObserver: drawingObserver)
        }
    }
    
    // important for determining port color; see `calculatePortColor`
    @MainActor func updateObserversConnectedItemsCache() {
        self.inputsObservers.forEach { $0.refreshConnectedCanvasItemsCache() }
        self.outputsObservers.forEach { $0.refreshConnectedCanvasItemsCache() }
    }
    
    // MARK: heavy perf cost due to human readable strings.**
    @MainActor
    func getDisplayTitle() -> String {
        // always prefer a custom name
        self.kind.getDisplayTitle(customName: self.title)
    }
    
    @MainActor
    var layerNodeId: LayerNodeId {
        LayerNodeId(self.id)
    }

    @MainActor
    var isGroupLayer: Bool {
        guard let layer = self.kind.getLayer else { return false }
        return layer == .group || layer == .realityView
    }
    
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

    @MainActor
    var patchNode: PatchNodeViewModel? {
        nodeType.patchNode
    }

    @MainActor
    var layerNode: LayerNodeViewModel? {
        nodeType.layerNode
    }
    
    @MainActor
    var componentNode: StitchComponentViewModel? {
        nodeType.componentNode
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

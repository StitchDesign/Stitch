//
//  VisibleNodesViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/11/22.
//

import SwiftUI
import StitchSchemaKit

typealias NodeEntityDict = [NodeId: NodeEntity]

@Observable
class VisibleNodesViewModel {
    // Storage for view models
    var nodes = NodesViewModelDict()

    // Saves location and zoom-specific data for groups
    var nodesByPage: NodesPagingDict = [.root: .init(zoomData: .init())]
}

extension VisibleNodesViewModel {
    var allNodeIds: IdSet {
        self.nodes.keys.toSet
    }

    var allViewModels: [NodeViewModel] {
        Array(self.nodes.values)
    }

    /// Returns list of view models to display given the actively selected group (or lack thereof).
    func getViewData(groupNodeFocused: GroupNodeId?) -> NodePageData? {
        self.nodesByPage.get(groupNodeFocused.nodePageType)
    }

    func getViewModel(_ id: NodeId) -> NodeViewModel? {
        self.nodes.get(id)
    }

    func removeOldViewModels(currentIds: NodeIdSet,
                             newIds: NodeIdSet,
                             isRestart: Bool = false) {
        let idsToRemove = isRestart ? currentIds : currentIds.subtracting(newIds)
        // log("removeOldViewModels: idsToRemove: \(idsToRemove)")
        idsToRemove.forEach {
            self.nodes.removeValue(forKey: $0)
        }
    }

    /// Mutating function which creates view models for each grouping view, using caching to save
    /// compute cost on view model creation.
    /// This funciton has two roles:
    /// 1. Create, update, and delete all node view models
    /// 2. Returns the specific list of view models to be visible.
    @MainActor
    func updateSchemaData(newNodes: [NodeEntity],
                          activeIndex: ActiveIndex,
                          graphDelegate: GraphDelegate) {

        let allNodesDict = newNodes.reduce(into: NodeEntityDict()) { result, schema in
            result.updateValue(schema, forKey: schema.id)
        }

        let existingNodePages: NodesPagingDict = self.nodesByPage

        let allNodeIds = newNodes.map(\.id).toSet

        let existingNodeIds = self.allNodeIds
        let incomingNodeIds = allNodeIds

        // Remove now unused view models
        self.removeOldViewModels(currentIds: existingNodeIds,
                                 newIds: incomingNodeIds)

        // Initialize node view data starting with groups
        self.updateNodesPagingDict(nodesDict: allNodesDict,
                                   existingNodePages: existingNodePages,
                                   activeIndex: activeIndex,
                                   graphDelegate: graphDelegate)
    }

    /// Returns all view data to be used by nodes in groups.
    @MainActor
    func updateNodesPagingDict(nodesDict: NodeEntityDict,
                               existingNodePages: NodesPagingDict,
                               activeIndex: ActiveIndex,
                               graphDelegate: GraphDelegate) {

        // Remove any groups in the node paging dict that no longer exist in GraphSchema:
        let existingGroupPages = self.nodesByPage.compactMap(\.key.getGroupNodePage).toSet
        let incomingGroupIds = nodesDict
            .compactMap { $0.value.parentGroupNodeId?.asGroupNodeId }
            .toSet

        // Check for groups (traversal levels) to add for position/zoom data
        for incomingGroupId in incomingGroupIds where !existingGroupPages.contains(incomingGroupId) {
            self.nodesByPage.updateValue(.init(zoomData: .init()),
                                         forKey: .group(incomingGroupId))
        }

        // Create node view models (if not yet created), establishing connection data later
        nodesDict.values.forEach { schema in
            if let node = self.nodes.get(schema.id) {
                node.updateNodeViewModelFromSchema(schema,
                                                   activeIndex: activeIndex)

                // Toggle output downstream connections to false, will correct below
                node.getRowObservers(.output).forEach {
                    $0.containsDownstreamConnection = false
                }
            } else {
                let newNode: NodeViewModel = .createNodeViewModelFromSchema(
                    schema,
                    activeIndex: activeIndex,
                    graphDelegate: graphDelegate)

                nodes.updateValue(newNode,
                                  forKey: newNode.id)
            }
        }

        // Build weak references to connected nodes
        nodesDict.values.forEach { nodeEntity in
            self.buildUpstreamReferences(nodeEntity: nodeEntity)
        }
    }

    @MainActor
    func buildUpstreamReferences(nodeEntity: NodeEntity) {
        guard let nodeViewModel = self.nodes.get(nodeEntity.id) else {
            #if DEBUG || DEV_DEBUG
            fatalError()
            #endif
            return
        }

        // Layers use keypaths
        if let layerEntity = nodeEntity.layerNodeEntity,
           let layerNodeViewModel = nodeViewModel.layerNode {
            layerEntity.layer.layerGraphNode.inputDefinitions.forEach { inputType in
                let schemaInput = layerEntity[keyPath: inputType.schemaPortKeyPath]
                let inputObserver = layerNodeViewModel[keyPath: inputType.layerNodeKeyPath]
                
                guard let connectedOutputCoordinate = schemaInput.upstreamConnection else {
                    inputObserver.upstreamOutputCoordinate = nil
                    return
                }
                
                // Check for connected row observer rather than just setting ID--makes for
                // a more robust check in ensuring the connection actually exists
                let connectedOutputObserver = self.getOutputRowObserver(for: connectedOutputCoordinate)
                inputObserver.upstreamOutputCoordinate = connectedOutputObserver?.id
                
                // Report to output observer that there's an edge (for port colors)
                // We set this to false on default above
                connectedOutputObserver?.containsDownstreamConnection = true
            }
        } else {
            nodeEntity.inputs.enumerated().forEach { portId, inputEntity in
                guard let inputObserver = nodeViewModel.getInputRowObserver(portId) else {
                    // TODO: humane demo crash with option picker node titled "Select Source"
                    //                #if DEBUG
                    //                fatalError()
                    //                #endif
                    return
                }
                
                guard let connectedOutputCoordinate = inputEntity.upstreamOutputCoordinate else {
                    inputObserver.upstreamOutputCoordinate = nil
                    return
                }
                
                // Check for connected row observer rather than just setting ID--makes for
                // a more robust check in ensuring the connection actually exists
                let connectedOutputObserver = self.getOutputRowObserver(for: connectedOutputCoordinate)
                inputObserver.upstreamOutputCoordinate = connectedOutputObserver?.id
                
                // Report to output observer that there's an edge (for port colors)
                // We set this to false on default above
                connectedOutputObserver?.containsDownstreamConnection = true
            }
        }   
    }

    func getVisibleNodes(at focusedGroup: NodeId?) -> NodeViewModels {
        self.allViewModels
            .filter { $0.parentGroupNodeId ==  focusedGroup }
    }

    // TODO: combine with getVisibleCanvasItems and just provide an additional param?
    @MainActor
    func getCanvasItems() -> CanvasItemViewModels {
        self.allViewModels.reduce(into: .init()) { partialResult, node in
            switch node.kind {
            case .patch, .group:
                    partialResult.append(node.canvasUIData)
            case .layer:
                partialResult.append(contentsOf: node.allRowObservers().compactMap(\.canvasUIData))
            }
        }
    }
    
    // TODO: "visible" is ambiguous between "canvas item is on-screen" vs "canvas item is at this traversal level"
    @MainActor
    func getVisibleCanvasItems(at focusedGroup: NodeId?) -> CanvasItemViewModels {
        self.allViewModels.reduce(into: .init()) { partialResult, node in
            switch node.kind {
            case .patch, .group:
                if node.canvasUIData.parentGroupNodeId == focusedGroup {
                    partialResult.append(node.canvasUIData)
                }
            case .layer:
                let visibleLayerRowsOnGraph = node.allRowObservers()
                    .compactMap { row in
                        if let canvasData = row.canvasUIData, canvasData.parentGroupNodeId == focusedGroup {
                            return canvasData
                        }
                        return nil
                    }
                partialResult.append(contentsOf: visibleLayerRowsOnGraph)
            }
        }
    }

    /// Obtains row observers directly from splitter patch nodes given its parent group node.
    @MainActor
    func getSplitterRowObservers(for groupNodeId: NodeId,
                                 type: SplitterType) -> NodeRowObservers {
        // find splitters inside this group node
        let allSplitterNodes = self.nodes.values
            .filter {
                $0.splitterType == type
            }

        // filter splitters relevant to this group node
        let splittersInThisGroup = allSplitterNodes
            .filter { splitterNode in
                splitterNode.parentGroupNodeId == groupNodeId
            }
            // sort new inputs/outputs by the date the splitter was created
            .sorted {
                ($0.patchNode?.splitterNode?.lastModifiedDate ?? Date.now) <
                    ($1.patchNode?.splitterNode?.lastModifiedDate ?? Date.now)
            }

        // get the first (and only) row observer for this splitter node
        let splitterRowObservers: NodeRowObservers = splittersInThisGroup
            // get the NodeViewModel for this splitter
            .compactMap { self.nodes.get($0.id) }
            .compactMap { node in
                switch node.splitterType {
                case .inline, .none:
                    // Shouldn't be called
                    fatalErrorIfDebug()
                    return nil
                case .input:
                    return node.getInputRowObserver(0)
                case .output:
                    return node.getOutputRowObserver(0)
                }
            }

        return splitterRowObservers
    }

    @MainActor
    func getInputSplitters(for id: NodeId) -> NodeRowObservers? {
        self._getSplitters(for: id, splitterType: .input)
    }

    @MainActor
    func getInputSplitterInputPorts(for id: NodeId) -> [InputPortViewData]? {
        if let observers = self.getInputSplitters(for: id) {
            return (0..<observers.count).map { portId in
                return InputPortViewData(portId: portId, nodeId: id)
            }
        }
        return nil
    }

    // Nil if not a group node or if group had no splitters for that splitter-type
    @MainActor
    private func _getSplitters(for id: NodeId, splitterType: SplitterType) -> NodeRowObservers? {

        let isGroup = self.isGroupNode(id)
        let splitters = self.getSplitterRowObservers(for: id, type: splitterType)

        guard isGroup else {
            #if DEBUG
            log("_getSplitters: id \(id) was not for group")
            #endif
            return nil
        }

        guard !splitters.isEmpty else {
            #if DEBUG
            log("_getSplitters: no splitters")
            #endif
            return nil
        }

        return splitters
    }

    func isGroupNode(_ id: NodeId) -> Bool {
        self.getViewModel(id)?.kind.isGroup ?? false
    }
    
    var patchNodes: NodesViewModelDict {
        self.nodes.filter {
            $0.value.patchNode.isDefined
        }
    }

    var layerNodes: NodesViewModelDict {
        self.nodes.filter {
            $0.value.layerNode.isDefined
        }
    }

    var groupNodes: NodesViewModelDict {
        self.nodes.filter {
            $0.value.kind == .group
        }
    }

    /// Updates cached data inside row observers.
    @MainActor
    func updateAllNodeViewData() {
        // Port view data first
        self.nodes.values.forEach { node in
            node.updateAllPortViewData()
        }
        
        // Connected nodes data relies on port view data so we call this later
        self.nodes.values.forEach { node in
            node.updateAllConnectedNodes()
        }
    }
    
    @MainActor
    func getOutputRowObserver(for coordinate: NodeIOCoordinate) -> NodeRowObserver? {
        self.nodes.get(coordinate.nodeId)?
            .getOutputRowObserver(for: coordinate.portType)
    }
}

extension InsertNodeMenuState {
    @MainActor
    func fakeNode(_ nodePosition: CGPoint) -> NodeViewModel? {

        // log("InsertNodeMenuState: fakeNode")

        // Note: Technically, zIndex of animating-node doesn't matter, since it sits above GraphBaseView,
        // and is removed when insert-animation finishes.
        //        let zIndex: ZIndex = 99999999
        let zIndex: ZIndex = 1

        guard let activeSelection = self.activeSelection else {
            // log("InsertNodeMenuState: fakeNode: no active selection")
            return nil
        }

        switch activeSelection.data {

        case .patch(let patch):
            return patch.getFakePatchNode(nodePosition.toCGSize, zIndex)

        case .layer(let layer):
            return layer.getFakeLayerNode(nodePosition.toCGSize, zIndex)

        default:
            // TODO: implement components-choice
            log("InsertNodeMenuState: had neither patch nor layer")
            return nil
        }
    }
}

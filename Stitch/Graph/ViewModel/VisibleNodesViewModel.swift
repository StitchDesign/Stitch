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

    @MainActor
    var allViewModels: CanvasItemViewModels {
        Array(self.nodes.values.flatMap { node in
            node.getAllCanvasObservers()
        })
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
            .flatMap { $0.value.canvasEntities }
            .compactMap { $0.parentGroupNodeId?.asGroupNodeId }
            .toSet

        // Check for groups (traversal levels) to add for position/zoom data
        for incomingGroupId in incomingGroupIds where !existingGroupPages.contains(incomingGroupId) {
            self.nodesByPage.updateValue(.init(zoomData: .init()),
                                         forKey: .group(incomingGroupId))
        }

        // Create node view models (if not yet created), establishing connection data later
        nodesDict.values.forEach { schema in
            if let node = self.nodes.get(schema.id) {
                node.update(from: schema)

                // Toggle output downstream connections to false, will correct below
                node.getAllOutputsObservers().forEach {
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
        
        // Sync port view models for applicable nodes
        self.nodes.values.forEach { node in
            switch node.nodeType {
            case .patch(let patchNode):
                // Syncs ports if nodes had inputs added/removed
                patchNode.canvasObserver.syncRowViewModels(inputRowObservers: patchNode.inputsObservers,
                                                           outputRowObservers: patchNode.outputsObservers)
                
            case .group(let canvasGroup):
                // Create port view models for group nodes once row observers have been established
                let inputRowObservers = self.getSplitterInputRowObservers(for: node.id)
                let outputRowObservers = self.getSplitterOutputRowObservers(for: node.id)
                canvasGroup.syncRowViewModels(inputRowObservers: inputRowObservers,
                                              outputRowObservers: outputRowObservers)
                
            default:
                return
            }
        }
    }

    @MainActor
    func buildUpstreamReferences(nodeEntity: NodeEntity) {
        guard let nodeViewModel = self.nodes.get(nodeEntity.id) else {
            fatalErrorIfDebug()
            return
        }

        // Layers use keypaths
        if let layerEntity = nodeEntity.layerNodeEntity,
           let layerNodeViewModel = nodeViewModel.layerNode {
            layerEntity.layer.layerGraphNode.inputDefinitions.forEach { inputType in
                let schemaInput = layerEntity[keyPath: inputType.schemaPortKeyPath]
                
                // Loop over ports for each layer input--multiple if in unpacked mode
                layerNodeViewModel[keyPath: inputType.layerNodeKeyPath].allInputData.forEach { inputData in
                    let inputObserver = inputData.rowObserver
                    let id = inputData.id
                    guard let inputSchemaData = schemaInput.getInputData(from: id.portType) else {
                        fatalErrorIfDebug()
                        return
                    }
                    
                    guard let connectedOutputCoordinate = inputSchemaData.inputPort.upstreamConnection else {
                        inputObserver.upstreamOutputCoordinate = nil
                        return
                    }
                    
                    // Check for connected row observer rather than just setting ID--makes for
                    // a more robust check in ensuring the connection actually exists
                    guard let connectedOutputObserver = self.getOutputRowObserver(for: connectedOutputCoordinate) else {
                        fatalErrorIfDebug()
                        return
                    }
                    inputObserver.upstreamOutputCoordinate = connectedOutputObserver.id
                    
                    // Report to output observer that there's an edge (for port colors)
                    // We set this to false on default above
                    connectedOutputObserver.containsDownstreamConnection = true
                }
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
                
                guard let connectedOutputCoordinate = inputEntity.upstreamConnection else {
                    inputObserver.upstreamOutputCoordinate = nil
                    return
                }
                
                // Check for connected row observer rather than just setting ID--makes for
                // a more robust check in ensuring the connection actually exists
                guard let connectedOutputObserver = self.getOutputRowObserver(for: connectedOutputCoordinate) else {
                    fatalErrorIfDebug()
                    return
                }
                
                inputObserver.upstreamOutputCoordinate = connectedOutputObserver.id
                
                // Report to output observer that there's an edge (for port colors)
                // We set this to false on default above
                connectedOutputObserver.containsDownstreamConnection = true
            }
        }   
    }

    @MainActor
    func getVisibleNodes(at focusedGroup: NodeId?) -> [NodeDelegate] {
        self.getVisibleCanvasItems(at: focusedGroup)
            .filter { $0.parentGroupNodeId ==  focusedGroup }
            .compactMap { $0.nodeDelegate }
    }

    @MainActor
    func getCanvasItems() -> CanvasItemViewModels {
        self.nodes.values.flatMap { node in
            switch node.nodeType {
            case .patch(let patchNode):
                return [patchNode.canvasObserver]
            case .layer(let layerNode):
                return layerNode.getAllCanvasObservers()
            case .group(let canvas):
                return [canvas]
            }
        }
    }
    
    // TODO: "visible" is ambiguous between "canvas item is on-screen" vs "canvas item is at this traversal level"
    @MainActor
    func getVisibleCanvasItems(at focusedGroup: NodeId?) -> CanvasItemViewModels {
        self.getCanvasItems()
            .filter { $0.parentGroupNodeId == focusedGroup }
    }

    /// Obtains input row observers directly from splitter patch nodes given its parent group node.
    @MainActor
    func getSplitterInputRowObservers(for groupNodeId: NodeId) -> [InputNodeRowObserver] {
        // find splitters inside this group node
        let allSplitterNodes: [PatchNodeViewModel] = self.nodes.values
            .compactMap { $0.patchNode }
            .filter {
                $0.splitterType == .input
            }

        // filter splitters relevant to this group node
        let splittersInThisGroup = allSplitterNodes
            .filter { splitterNode in
                splitterNode.canvasObserver.parentGroupNodeId == groupNodeId
            }
            // sort new inputs/inputs by the date the splitter was created
            .sorted {
                ($0.splitterNode?.lastModifiedDate ?? Date.now) <
                    ($1.splitterNode?.lastModifiedDate ?? Date.now)
            }

        // get the first (and only) row observer for this splitter node
        let splitterRowObservers: [InputNodeRowObserver] = splittersInThisGroup
            // get the NodeViewModel for this splitter
            .compactMap { self.nodes.get($0.id) }
            .compactMap { node in
                switch node.splitterType {
                case .input:
                    return node.getInputRowObserver(0)
                default:
                    // Shouldn't be called
                    fatalErrorIfDebug()
                    return nil
                }
            }

        return splitterRowObservers
    }
    
    /// Obtains output row observers directly from splitter patch nodes given its parent group node.
    @MainActor
    func getSplitterOutputRowObservers(for groupNodeId: NodeId) -> [OutputNodeRowObserver] {
        // find splitters inside this group node
        let allSplitterNodes: [PatchNodeViewModel] = self.nodes.values
            .compactMap { $0.patchNode }
            .filter {
                $0.splitterType == .output
            }

        // filter splitters relevant to this group node
        let splittersInThisGroup = allSplitterNodes
            .filter { splitterNode in
                splitterNode.canvasObserver.parentGroupNodeId == groupNodeId
            }
            // sort new inputs/outputs by the date the splitter was created
            .sorted {
                ($0.splitterNode?.lastModifiedDate ?? Date.now) <
                    ($1.splitterNode?.lastModifiedDate ?? Date.now)
            }

        // get the first (and only) row observer for this splitter node
        let splitterRowObservers: [OutputNodeRowObserver] = splittersInThisGroup
            // get the NodeViewModel for this splitter
            .compactMap { self.nodes.get($0.id) }
            .compactMap { node in
                switch node.splitterType {
                case .output:
                    return node.getOutputRowObserver(0)
                default:
                    // Shouldn't be called
                    fatalErrorIfDebug()
                    return nil
                }
            }

        return splitterRowObservers
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
        // Connected nodes data relies on port view data so we call this later
        self.nodes.values.forEach { node in
            node.updateAllConnectedNodes()
        }
    }
    
    @MainActor
    func getOutputRowObserver(for coordinate: NodeIOCoordinate) -> OutputNodeRowObserver? {
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

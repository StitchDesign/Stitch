//
//  VisibleNodesViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/11/22.
//

import SwiftUI
import StitchSchemaKit

@Observable
final class VisibleNodesViewModel: Sendable {
    // Storage for view models
    @MainActor var nodes = NodesViewModelDict()

    // Saves location and zoom-specific data for groups
    @MainActor var nodesByPage: NodesPagingDict // = [.root: .init()]
    
    @MainActor var visibleCanvasIds = Set<CanvasItemId>()
    
    // Signals to SwiftUI layout when new sizing data is needed;
    // tracked here to fix stutter that exists if we reset cache before
    // a dispatch updates it on subsequent call.
    @MainActor var needsInfiniteCanvasCacheReset = true
    @MainActor var infiniteCanvasCache: InfiniteCanvas.Cache = .init()
    
    @MainActor init(localPosition: CGPoint) {
        self.nodesByPage = [.root: .init(localPosition: localPosition)]
    }
}

extension VisibleNodesViewModel {
    @MainActor
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
    @MainActor
    func getViewData(groupNodeFocused: NodeId?) -> NodePageData? {
        self.nodesByPage.get(groupNodeFocused.nodePageType)
    }

    @MainActor
    func getViewModel(_ id: NodeId) -> NodeViewModel? {
        self.nodes.get(id)
    }
    
    // Provide an API more consistent with GraphState, GraphDelegate
    @MainActor
    func getNode(_ id: NodeId) -> NodeViewModel? {
        self.getViewModel(id)
    }

    @MainActor
    func removeOldViewModels(currentIds: NodeIdSet,
                             newIds: NodeIdSet,
                             isRestart: Bool = false) {
        let idsToRemove = isRestart ? currentIds : currentIds.subtracting(newIds)
        // log("removeOldViewModels: idsToRemove: \(idsToRemove)")
        idsToRemove.forEach {
            self.nodes.removeValue(forKey: $0)
        }
    }


    /// Returns all view data to be used by nodes in groups.
    @MainActor
    func updateNodesPagingDict(components: [UUID: StitchMasterComponent],
                               graphFrame: CGRect,
                               parentGraphPath: [UUID]) {

        // Remove any groups in the node paging dict that no longer exist in GraphSchema:
        let existingGroupPages = self.nodesByPage.compactMap(\.key.getGroupNodePage).toSet
        let incomingGroupIds = self.nodes.values
            .flatMap { $0.getAllCanvasObservers() }
            .compactMap { $0.parentGroupNodeId }
            .toSet

        // Check for groups (traversal levels) to add for position/zoom data
        for incomingGroupId in incomingGroupIds where !existingGroupPages.contains(incomingGroupId) {
            
            let westernMostNode = GraphState.westernMostNode(
                incomingGroupId,
                // Canvas items at this new group's traversal level
                canvasItems: self.getVisibleCanvasItems(at: incomingGroupId))
            
            let startOffset: CGPoint = westernMostNode.map { calculateMove(graphFrame, $0.position) } ?? ABSOLUTE_GRAPH_CENTER
                        
            self.nodesByPage.updateValue(NodePageData(localPosition: startOffset),
                                         forKey: .group(incomingGroupId))
        }

        // Toggle output downstream connections to false, will correct later
        self.nodes.values.forEach { node in
            node.getAllOutputsObservers().forEach {
                $0.containsDownstreamConnection = false
            }
        }
        
        // Build weak references to connected nodes
        self.nodes.values.forEach { node in
            self.buildUpstreamReferences(nodeViewModel: node)
        }
        
        // Sync port view models for applicable nodes
        self.nodes.values.forEach { node in
            switch node.nodeType {
            case .patch(let patchNode):
                // Syncs ports if nodes had inputs added/removed
                patchNode.canvasObserver.syncRowViewModels(inputRowObservers: patchNode.inputsObservers,
                                                           outputRowObservers: patchNode.outputsObservers,
                                                           // Not relevant
                                                           unpackedPortParentFieldGroupType: nil,
                                                           unpackedPortIndex: nil)
                
            case .group(let canvasGroup):
                // Create port view models for group nodes once row observers have been established
                let inputRowObservers = self.getSplitterInputRowObservers(for: node.id)
                let outputRowObservers = self.getSplitterOutputRowObservers(for: node.id)
                canvasGroup.syncRowViewModels(inputRowObservers: inputRowObservers,
                                              outputRowObservers: outputRowObservers,
                                              // Not relevant
                                              unpackedPortParentFieldGroupType: nil,
                                              unpackedPortIndex: nil)
                
                // Initializes view models for canvas
                guard let node = canvasGroup.nodeDelegate else {
                    fatalErrorIfDebug()
                    return
                }
                
                assertInDebug(node.kind == .group)
                
                canvasGroup.initializeDelegate(node,
                                               unpackedPortParentFieldGroupType: nil,
                                               unpackedPortIndex: nil)
                
            case .component(let componentViewModel):
                // Similar logic to patch nodes, where we have inputs/outputs observers stored directly in component
                componentViewModel.canvas.syncRowViewModels(inputRowObservers: componentViewModel.inputsObservers,
                                                            outputRowObservers: componentViewModel.outputsObservers,
                                                            unpackedPortParentFieldGroupType: nil,
                                                            unpackedPortIndex: nil)

            case .layer(let layerNode):
                // Special case: we must re-initialize the group orientation input, since its first initialization happens before we have constructed the layer view models that can tell us all the parent's children
                if layerNode.layer == .group {
                    layerNode.blockOrUnblockFields(
                        newValue: layerNode.orientationPort.activeValue,
                        layerInput: .orientation)
                }
            }
        }
    }

    @MainActor
    func buildUpstreamReferences(nodeViewModel: NodeViewModel) {
        // Layers use keypaths
        if let layerNodeViewModel = nodeViewModel.layerNode {
            layerNodeViewModel.layer.layerGraphNode.inputDefinitions.forEach { inputType in
                
                // Loop over ports for each layer input--multiple if in unpacked mode
                layerNodeViewModel[keyPath: inputType.layerNodeKeyPath].allInputData.forEach { inputData in
                    let inputObserver = inputData.rowObserver
                    inputObserver.buildUpstreamReference()
                }
            }
        } else {
            nodeViewModel.getAllInputsObservers().enumerated().forEach { portId, inputObserver in
                inputObserver.buildUpstreamReference()
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
            case .component(let component):
                return [component.canvas]
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
    func getSplitterInputRowObservers(for groupNodeId: NodeId?) -> [InputNodeRowObserver] {
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
    func getSplitterOutputRowObservers(for groupNodeId: NodeId?) -> [OutputNodeRowObserver] {
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

    @MainActor
    func isGroupNode(_ id: NodeId) -> Bool {
        self.getViewModel(id)?.kind.isGroup ?? false
    }
    
    @MainActor
    var patchNodes: NodesViewModelDict {
        self.nodes.filter {
            $0.value.patchNode.isDefined
        }
    }

    @MainActor
    var layerNodes: NodesViewModelDict {
        self.nodes.filter {
            $0.value.layerNode.isDefined
        }
    }

    @MainActor
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
    
    @MainActor
    func setAllNodesVisible() {
        self.visibleCanvasIds = self.allViewModels.map(\.id).toSet
    }
    
    @MainActor
    /// Updates node visibility data.
    func resetCache() {
        self.needsInfiniteCanvasCacheReset = true
        self.setAllNodesVisible()
        
        // Fixes issues where new rows don't have port locations
        for node in self.nodes.values {
            node.patchCanvasItem?.updatePortLocations()
        }
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

//
//  State.swift
//  Stitch
//
//  Created by cjc on 1/13/21.
//

import AudioKit
import AVFoundation
import CoreML
import CoreMotion
import Foundation
import StitchSchemaKit
import StitchEngine
import SwiftUI
import Vision

@Observable
final class GraphState: Sendable {
    typealias CachedPortUI = NodePortType<NodeViewModel>
    typealias NodePortCacheSet = Set<CachedPortUI>
    
    // Updated when connections, new nodes etc change
    let topologicalData: GraphTopologicalData<NodeViewModel>
    
    let saveLocation: [UUID]
    
    @MainActor var id = UUID()
    @MainActor var name: String = STITCH_PROJECT_DEFAULT_NAME
    @MainActor var migrationWarning: StringIdentifiable?
    
    @MainActor var commentBoxesDict = CommentBoxesDict()
    
    let visibleNodesViewModel: VisibleNodesViewModel
    @MainActor let edgeDrawingObserver = EdgeDrawingObserver()
    
    @MainActor var selectedEdges = Set<PortEdgeUI>()
    
    // Hackiness for handling edge case in our UI where somehow
    // UIKit node drag and SwiftUI port drag can happen at sometime.
    @MainActor var nodeIsMoving = false
    @MainActor var outputDragStartedCount = 0
    
    // Keeps track of interaction nodes and their selected layer
    @MainActor var dragInteractionNodes = [LayerNodeId: NodeIdSet]()
    @MainActor var pressInteractionNodes = [LayerNodeId: NodeIdSet]()
    @MainActor var scrollInteractionNodes = [LayerNodeId: NodeIdSet]()
    
    // Ordered list of layers in sidebar
    let layersSidebarViewModel: LayersSidebarViewModel
    
    // Cache of ordered list of preview layer view models;
    // updated in various scenarious, e.g. sidebar list item dragged
    @MainActor var cachedOrderedPreviewLayers: LayerDataList = .init()
    
    // Updates to true if a layer's input should re-sort preview layers (z-index, masks etc)
    // Checked at the end of graph calc for efficient updating
    @MainActor var shouldResortPreviewLayers: Bool = false
    
    // Used in rotation modifier to know whether view receives a pin;
    // updated whenever preview layers cache is updated.
    @MainActor var pinMap = RootPinMap()
    @MainActor var flattenedPinMap = PinMap()
    
    // Tracks all created and imported components
    @MainActor var components: [UUID: StitchMasterComponent] = [:]
    
    // Maps a MediaKey to some URL
    @MainActor var mediaLibrary: MediaLibrary = [:]
    
    // Tracks nodes with camera enabled
    @MainActor var enabledCameraNodeIds = NodeIdSet()
    
    // TODO: can a given graph (or even *device*) really ever have more than one motion manager? There's only one hardware.
    @MainActor var motionManagers = StitchMotionManagersDict()
    
    // Tracks IDs for rows that need to be updated for the view. Cached here for perf so we can throttle view updates.
    @MainActor var portsToUpdate: NodePortCacheSet = .init()

    /// Subscribed by view to trigger graph view update based on data changes.
    @MainActor var graphUpdaterId: Int = .zero
    
    @MainActor var lastEncodedDocument: GraphEntity
    @MainActor weak var documentDelegate: StitchDocumentViewModel?
    @MainActor weak var documentEncoderDelegate: (any DocumentEncodable)?
    
    @MainActor
    init(from schema: GraphEntity,
         localPosition: CGPoint,
         nodes: NodesViewModelDict,
         components: MasterComponentsDict,
         mediaFiles: [URL],
         saveLocation: [UUID]) {
        self.visibleNodesViewModel = VisibleNodesViewModel(localPosition: localPosition)
        self.lastEncodedDocument = schema
        self.saveLocation = saveLocation
        self.id = schema.id
        self.name = schema.name
        self.layersSidebarViewModel = .init()
        self.topologicalData = .init()
        self.commentBoxesDict.sync(from: schema.commentBoxes)
        self.components = components
        self.visibleNodesViewModel.nodes = nodes
        
        if let stringWarning = schema.migrationWarning {
            self.migrationWarning = .init(rawValue: stringWarning)
        }
        
        self.syncMediaFiles(mediaFiles)
        self.layersSidebarViewModel.sync(from: schema.orderedSidebarLayers)
    }
}

extension GraphState {
    @MainActor
    var orderedSidebarLayers: [SidebarItemGestureViewModel] {
        self.layersSidebarViewModel.items
    }
    
    @MainActor
    convenience init(from schema: GraphEntity,
                     localPosition: CGPoint,
                     saveLocation: [UUID],
                     encoder: (any DocumentEncodable)) async {
        guard let decodedFiles = await encoder.getDecodedFiles() else {
            fatalErrorIfDebug()
            self.init()
            return
        }
        
        let components =  decodedFiles.components.createComponentsDict(parentGraph: nil)
        
        var nodes = NodesViewModelDict()
        for nodeEntity in schema.nodes {
            let newNode = await NodeViewModel(from: nodeEntity,
                                              components: components,
                                              parentGraphPath: saveLocation)
            nodes.updateValue(newNode, forKey: newNode.id)
        }
        
        self.init(from: schema,
                  localPosition: localPosition,
                  nodes: nodes,
                  components: components,
                  mediaFiles: decodedFiles.mediaFiles,
                  saveLocation: saveLocation)
    }
    
    @MainActor
    func initializeDelegate(document: StitchDocumentViewModel,
                            documentEncoderDelegate: any DocumentEncodable) {
        
        self.documentDelegate = document
        self.documentEncoderDelegate = documentEncoderDelegate
        
        self.layersSidebarViewModel.initializeDelegate(graph: self)
        
        self.nodes.values.forEach { $0.initializeDelegate(graph: self,
                                                          document: document) }
        
        // Set up component graphs
        self.components.values.forEach {
            $0.initializeDelegate(parentGraph: self)
        }
        
        self.updateTopologicalData()
        
        self.visibleNodesViewModel
            .updateNodesPagingDict(components: self.components,
                                   graphFrame: self.graphUI.frame,
                                   parentGraphPath: self.saveLocation)
        
        // Update connected port data
        self.visibleNodesViewModel.updateAllNodeViewData()
        
        if !document.isDebugMode {
            self.updateOrderedPreviewLayers()
            
            // Calculate graph
            self.initializeGraphComputation()
        } else {
            // Update all fields since calculation is skipped
            self.updatePortViews()
        }
    }

    @MainActor
    var graphUI: GraphUIState {
        guard let graphUI = self.documentDelegate?.graphUI else {
            return GraphUIState(isPhoneDevice: false)
        }
        
        return graphUI
    }
    
    @MainActor
    var storeDelegate: StoreDelegate? {
        self.documentDelegate?.storeDelegate
    }
    
    @MainActor
    var nodes: [UUID : NodeViewModel] {
        get {
            self.visibleNodesViewModel.nodes
        }
        set(newValue) {
            self.visibleNodesViewModel.nodes = newValue
        }
    }
    
    @MainActor
    var groupNodeFocused: NodeId? {
        self.graphUI.groupNodeFocused?.groupNodeId
    }
    
    @MainActor
    var nodesDict: NodesViewModelDict {
        self.nodes
    }

    @MainActor
    var safeAreaInsets: SafeAreaInsets {
        self.graphUI.safeAreaInsets
    }
    
    @MainActor
    var isFullScreenMode: Bool {
        self.graphUI.isFullScreenMode
    }
    
    @MainActor
    func getMediaUrl(forKey key: MediaKey) -> URL? {
        self.mediaLibrary.get(key)
    }
    
    @MainActor var multiselectInputs: LayerInputPortSet? {
        self.graphUI.propertySidebar.inputsCommonToSelectedLayers
    }
    
    func undoDeletedMedia(mediaKey: MediaKey) async -> URLResult {
        await self.documentEncoderDelegate?.undoDeletedMedia(mediaKey: mediaKey) ?? .failure(.copyFileFailed)
    }
    
    @MainActor
    var allComponents: [StitchComponentViewModel] {
        self.nodes.values.flatMap { node -> [StitchComponentViewModel] in
            guard let nodeComponent = node.nodeType.componentNode else {
                return []
            }
            
            return [nodeComponent] + nodeComponent.graph.allComponents
        }
    }
    
    @MainActor
    var allComponentGraphs: [GraphState] {
        self.allComponents.map { $0.graph }
    }
    
    /// Finds graph states for a component at this hierarchy.
    @MainActor
    func findComponentGraphStates(componentId: UUID) -> [GraphState] {
        self.nodes.values
            .compactMap { node in
                if let component = node.componentNode,
                   component.componentId == componentId {
                    return component.graph
                }
                
                return nil
            }
    }
    
    /// Finds graph state given a node ID of some component node.
    @MainActor
    func findComponentGraphState(_ nodeId: UUID) -> GraphState? {
        self.documentDelegate?.allComponents.first { $0.id == nodeId }?.graph ?? nil
    }
    
    /// Syncs visible nodes and topological data when persistence actions take place.
    @MainActor
    func updateGraphData() {
        // Update parent graphs first if this graph is a component
        // Order here needed so parent components know if there are input/output changes
        if let parentGraph = self.parentGraph {
            parentGraph.updateGraphData()
        }
        
        if let document = self.documentDelegate,
           let encoderDelegate = self.documentEncoderDelegate {
            self.initializeDelegate(document: document,
                                    documentEncoderDelegate: encoderDelegate)
        }
        
        // Updates node visibility data
        self.visibleNodesViewModel.resetCache()
    }
    
    @MainActor
    var isSidebarFocused: Bool {
        get {
            self.graphUI.isSidebarFocused
        }
        set(newValue) {
            self.graphUI.isSidebarFocused = newValue
        }
    }
}

extension GraphState {
    var sidebarSelectionState: LayersSidebarViewModel.SidebarSelectionState {
        self.layersSidebarViewModel.selectionState
    }
    
    @MainActor func createSchema() -> GraphEntity {
        let nodes = self.visibleNodesViewModel.nodes.values
            .map { $0.createSchema() }
        let commentBoxes = self.commentBoxesDict.values.map { $0.createSchema() }
        
        let graph = GraphEntity(id: self.projectId,
                                name: self.name,
                                nodes: nodes,
                                orderedSidebarLayers: self.layersSidebarViewModel.createdOrderedEncodedData(),
                                commentBoxes: commentBoxes)
        return graph
    }
    
    @MainActor
    func syncNodes(with entities: [NodeEntity]) async {
        let newDictionary = await self.visibleNodesViewModel.nodes
            .sync(with: entities,
                  updateCallback: { nodeViewModel, nodeSchema in
            await nodeViewModel.update(from: nodeSchema,
                                       components: self.components)
        }) { nodeSchema in
            await NodeViewModel(from: nodeSchema,
                                components: self.components,
                                parentGraphPath: self.saveLocation)
        }
        
        self.visibleNodesViewModel.nodes = newDictionary
    }
    
    @MainActor
    func syncNodes(with entities: [NodeEntity]) {
        let newDictionary = self.visibleNodesViewModel.nodes
            .sync(with: entities,
                  updateCallback: { nodeViewModel, nodeSchema in
            nodeViewModel.update(from: nodeSchema)
        }) { nodeSchema in
            let nodeType = NodeViewModelType(from: nodeSchema.nodeTypeEntity,
                                             nodeId: nodeSchema.id)
            return NodeViewModel(from: nodeSchema,
                                 nodeType: nodeType)
        }
        
        self.visibleNodesViewModel.nodes = newDictionary
    }
    
    @MainActor
    private func updateSynchronousProperties(from schema: GraphEntity) {
        assertInDebug(self.id == schema.id)
        self.name = schema.name
        self.layersSidebarViewModel.update(from: schema.orderedSidebarLayers)
    }
    
    @MainActor func updateAsync(from schema: GraphEntity) async {
        self.updateSynchronousProperties(from: schema)
        
        if let decodedFiles = await self.documentEncoderDelegate?.getDecodedFiles() {
            self.importedFilesDirectoryReceived(mediaFiles: decodedFiles.mediaFiles,
                                                components: decodedFiles.components)
        }
        
        await self.syncNodes(with: schema.nodes)
        
        // Determines if graph data needs updating
        self.graphUpdaterId = self.calculateGraphUpdaterId()
    }
    
    // Used with copy-paste / duplication
    @MainActor func updateSync(from schema: GraphEntity) {
        self.updateSynchronousProperties(from: schema)
        
        Task { [weak self] in
            // Async update data correctly
            await self?.updateAsync(from: schema)
        }
        
        self.syncNodes(with: schema.nodes)
        
        // Determines if graph data needs updating
        self.graphUpdaterId = self.calculateGraphUpdaterId()
    }
    
    @MainActor func onPrototypeRestart() {
        self.nodes.values.forEach { $0.onPrototypeRestart() }
        self.initializeGraphComputation()
    }
    
    @MainActor
    var localPosition: CGPoint {
        self.documentDelegate?.localPosition ?? ABSOLUTE_GRAPH_CENTER
    }
    
    @MainActor
    var previewWindowBackgroundColor: Color {
        self.documentDelegate?.previewWindowBackgroundColor ?? .LAYER_DEFAULT_COLOR
    }
    
    @MainActor
    func getInputRowObserver(_ id: NodeIOCoordinate) -> InputNodeRowObserver? {
        self.getNodeViewModel(id.nodeId)?.getInputRowObserver(for: id.portType)
    }
    
    @MainActor
    var activeIndex: ActiveIndex {
        self.graphUI.activeIndex
    }
    
    @MainActor
    var llmRecording: LLMRecordingState {
        self.documentDelegate?.llmRecording ?? .init()
    }
    
    @MainActor
    var graphStepManager: GraphStepManager {
        guard let document = self.documentDelegate else {
//            fatalErrorIfDebug()
            log("graphStepManager: did not have a document delegate")
            return .init()
        }
        
        return document.graphStepManager
    }
    
    @MainActor
    func getBroadcasterNodesAtThisTraversalLevel() -> [NodeDelegate] {
        self.visibleNodesViewModel.getVisibleNodes(at: self.graphUI.groupNodeFocused?.groupNodeId)
            .compactMap { node in
                guard node.kind == .patch(.wirelessBroadcaster) else {
                    return nil
                }
                
                return node
            }
    }
    
    // TODO: highestZIndex also needs to take into account comment boxes' z-indices
    @MainActor
    var highestZIndex: Double {
        let zIndices = self.visibleNodesViewModel
            .nodes.values
            .flatMap { $0.getAllCanvasObservers() }
            .map { $0.zIndex }
        return zIndices.max() ?? 0
    }

    /// Creases a unique hash based on view data which if changes, requires graph data update.
    @MainActor
    func calculateGraphUpdaterId() -> Int {
        var hasher = Hasher()
        
        let nodes = self.nodes
        
        let allInputsObservers = nodes.values
            .flatMap { $0.getAllInputsObservers() }
        
        // Track overall node count
        let nodeCount = nodes.keys.count
        
        // Track graph canvas items count
        let canvasItems = self.getVisibleCanvasItems().count

        // Tracks edge changes to reset cached data
        let upstreamConnections = allInputsObservers
            .map { $0.upstreamOutputCoordinate }
        
        // Tracks manual edits
        let manualEdits: [PortValue] = allInputsObservers
            .compactMap {
                guard $0.upstreamOutputCoordinate == nil else {
                    return nil
                }
                
                return $0.activeValue
            }
        
        // Track group node ID, which fixes edges when traversing
        let groupNodeIdFocused = self.graphUI.groupNodeFocused
        
        hasher.combine(nodeCount)
        hasher.combine(canvasItems)
        hasher.combine(upstreamConnections)
        hasher.combine(manualEdits)
        hasher.combine(groupNodeIdFocused)
        
        return hasher.finalize()
    }
    
    @MainActor
    func encodeProjectInBackground(temporaryURL: URL? = nil,
                                   willUpdateUndoHistory: Bool = true) {
        self.documentEncoderDelegate?.encodeProjectInBackground(from: self,
                                                                temporaryUrl: temporaryURL,
                                                                willUpdateUndoHistory: willUpdateUndoHistory)
        
        // Updates graph data when changed
        let newViewId = self.calculateGraphUpdaterId()
        if self.graphUpdaterId != newViewId {
            self.graphUpdaterId = newViewId
        }
        
        // If debug mode, make sure fields are updated as we aren't using calculate
        // to update them
        // MARK: should move to delegate, however this works fine for now
        if self.documentDelegate?.isDebugMode ?? false {
            self.updatePortViews()
        }
    }
    
    @MainActor
    func encodeProjectInBackground(temporaryURL: URL? = nil,
                                   undoEvents: [Action],
                                   willUpdateUndoHistory: Bool = true) {
        self.documentEncoderDelegate?.encodeProjectInBackground(from: self,
                                                                undoEvents: undoEvents,
                                                                temporaryUrl: temporaryURL,
                                                                willUpdateUndoHistory: willUpdateUndoHistory)
    }
    
    @MainActor
    func getPatchNode(id nodeId: NodeId) -> PatchNode? {
        self.visibleNodesViewModel.patchNodes.get(nodeId)
    }
    
    @MainActor
    var patchNodes: NodesViewModelDict {
        self.visibleNodesViewModel.patchNodes
    }
    
    @MainActor
    var layerNodes: NodesViewModelDict {
        self.visibleNodesViewModel.layerNodes
    }
    
    @MainActor
    var groupNodes: NodesViewModelDict {
        self.visibleNodesViewModel.groupNodes
    }
    
    /*
     Primarily used for NodeViewModels, which are used in UI and during graph eval
     
     Secondarily used in some helpers for creating a GraphState that we then feed into GraphSchema
     - second use-case ideally removed in the future
     */
    @MainActor
    func updateNode(_ node: NodeViewModel) {
        self.visibleNodesViewModel.nodes
            .updateValue(node, forKey: node.id)
    }
    
    @MainActor
    func updatePatchNode(_ patchNode: PatchNode) {
        self.updateNode(patchNode)
    }
    
    // MISC HELPERS
    
    @MainActor
    func getInputValues(coordinate: InputCoordinate) -> PortValues? {
        self.visibleNodesViewModel.getViewModel(coordinate.nodeId)?
            .getInputRowObserver(for: coordinate.portType)?
            .allLoopedValues
    }
    
    @MainActor
    func getInputObserver(coordinate: InputCoordinate) -> InputNodeRowObserver? {
        self.visibleNodesViewModel.getViewModel(coordinate.nodeId)?
            .getInputRowObserver(for: coordinate.portType)
    }
    
    @MainActor func getOutputObserver(coordinate: OutputPortViewData) -> OutputNodeRowObserver? {
        self.getCanvasItem(coordinate.canvasId)?
            .outputViewModels[safe: coordinate.portId]?
            .rowDelegate
    }
    
    @MainActor func getInputRowViewModel(for rowId: NodeRowViewModelId,
                                         nodeId: NodeId) -> InputNodeRowViewModel? {
        guard let node = self.getNodeViewModel(nodeId) else {
            return nil
        }
        
        return node.getInputRowViewModel(for: rowId)
    }
    
    @MainActor func getOutputRowViewModel(for rowId: NodeRowViewModelId,
                                          nodeId: NodeId) -> OutputNodeRowViewModel? {
        guard let node = self.getNodeViewModel(nodeId) else {
            return nil
        }
        
        return node.getOutputRowViewModel(for: rowId)
    }
    
    @MainActor
    func getNode(_ id: NodeId) -> NodeViewModel? {
        self.getNodeViewModel(id)
    }
    
    @MainActor
    func getCanvasItem(_ id: CanvasItemId) -> CanvasItemViewModel? {
        switch id {
        case .node(let x):
            return self.getNodeViewModel(x)?
                .getAllCanvasObservers()
                .first { $0.id == id }
        case .layerInput(let x):
            return self.getLayerInputOnGraph(x)?.canvasItemDelegate
        case .layerOutput(let x):
            return self.getLayerOutputOnGraph(x)?.canvasItemDelegate
        }
    }
    
    @MainActor
    func getCanvasItem(inputId: NodeIOCoordinate) -> CanvasItemViewModel? {
        guard let node = self.getNodeViewModel(inputId.nodeId) else {
            return nil
        }
        
        return node.getAllCanvasObservers()
            .first { canvasItem in
                canvasItem.inputViewModels.contains { rowViewModel in
                    guard let rowObserver = rowViewModel.rowDelegate else {
                        return false
                    }
                    return rowObserver.id == inputId
                }
            }
    }
    
    @MainActor
    func getCanvasItem(outputId: NodeIOCoordinate) -> CanvasItemViewModel? {
        guard let node = self.getNodeViewModel(outputId.nodeId) else {
            return nil
        }
        
        return node.getAllCanvasObservers()
            .first { canvasItem in
                canvasItem.outputViewModels.contains { rowViewModel in
                    guard let rowObserver = rowViewModel.rowDelegate else {
                        return false
                    }
                    return rowObserver.id == outputId
                }
            }
    }
    
    // TODO: will look slightly different once inputs live on PatchNodeViewModel and LayerNodeViewModel instead of just NodeViewModel
    @MainActor
    func getLayerInputOnGraph(_ id: LayerInputCoordinate) -> InputNodeRowViewModel? {
        guard let canvasItem = self.getNodeViewModel(id.node)?.layerNode?[keyPath: id.keyPath.layerNodeKeyPath].canvasObserver else {
            return nil
        }
        
        return self.getInputRowViewModel(for: .init(graphItemType: .node(canvasItem.id),
                                                    nodeId: id.node,
                                                    portId: 0),
                                         nodeId: id.node)
    }
    
    @MainActor
    func getLayerOutputOnGraph(_ id: LayerOutputCoordinate) -> OutputNodeRowViewModel? {
        guard let canvasItem = self.getNodeViewModel(id.node)?.layerNode?.outputPorts[safe: id.portId]?.canvasObserver else {
            return nil
        }
        
        return self.getOutputRowViewModel(for: .init(graphItemType: .node(canvasItem.id),
                                                     nodeId: id.node,
                                                     portId: 0),
                                          nodeId: id.node)
    }
    
    @MainActor
    func getNodeViewModel(_ id: NodeId) -> NodeViewModel? {
        self.visibleNodesViewModel.getViewModel(id)
    }
    
    /// Gets all possible canvas observers for some node.
    /// For patches there is always one canvas observer. For layers there are 0 to many observers.
    @MainActor
    func getCanvasNodeViewModels(from nodeId: NodeId) -> [CanvasItemViewModel] {
        guard let node = self.getNodeViewModel(nodeId) else {
            return []
        }
        
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
    
    @MainActor
    func getLayerNode(id: NodeId) -> NodeViewModel? {
        self.getNodeViewModel(id)
    }
    
    @MainActor
    func getVisibleNodes() -> [NodeDelegate] {
        self.visibleNodesViewModel
            .getVisibleNodes(at: self.graphUI.groupNodeFocused?.groupNodeId)
    }
    
    @MainActor
    func getVisibleCanvasItems() -> CanvasItemViewModels {
        self.visibleNodesViewModel
            .getVisibleCanvasItems(at: self.graphUI.groupNodeFocused?.groupNodeId)
    }
    
    @MainActor
    func getCanvasItems() -> CanvasItemViewModels {
        self.visibleNodesViewModel.getCanvasItems()
    }
    
    @MainActor
    var keyboardNodes: NodeIdSet {
        Array(self.nodes
            .values
            .filter { $0.patch == .keyboard }
            .map(\.id))
        .toSet
    }
    
    @MainActor
    func getLayerChildren(for groupId: NodeId) -> NodeIdSet {
        self.nodes.values
            .filter { $0.layerNode?.layerGroupId == groupId }
            .map { $0.id }
            .toSet
    }
    
    // The children of a ui group node are better described as 'canvas items',
    // since a ui group node is really a grouping of canvas items (patch nodes + layer inputs on graph) rather than nodes (patch nodes + full layer nodes)
    @MainActor
    func getGroupNodeChildren(for groupId: NodeId) -> CanvasItemIdSet {
        self.nodes.values
            .flatMap { $0.getAllCanvasObservers() }
            .filter { $0.parentGroupNodeId == groupId }
            .map(\.id)
            .toSet
    }
    
   
    @MainActor
    func getInputCoordinate(from viewData: InputPortViewData) -> NodeIOCoordinate? {
        guard let node = self.getCanvasItem(viewData.canvasId),
              let inputRow = node.inputViewModels[safe: viewData.portId]?.rowDelegate else {
            return nil
        }
        
        return inputRow.id
    }
    
    @MainActor
    func getOutputCoordinate(from viewData: OutputPortViewData) -> NodeIOCoordinate? {
        guard let node = self.getCanvasItem(viewData.canvasId),
              let outputRow = node.outputViewModels[safe: viewData.portId]?.rowDelegate else {
            return nil
        }
        
        return outputRow.id
    }
    
    @MainActor static func createEmpty() -> GraphState {
        .init()
    }
     
    // aka createEmpty
    @MainActor convenience init() {
        self.init(from: .init(id: .init(),
                              name: STITCH_PROJECT_DEFAULT_NAME,
                              nodes: [],
                              orderedSidebarLayers: [],
                              commentBoxes: []),
                  localPosition: ABSOLUTE_GRAPH_CENTER,
                  nodes: [:],
                  components: [:],
                  mediaFiles: [],
                  saveLocation: [])
    }
    
    // used by e.g. Delay node
    /// Updates values at a specific output loop index.
    @MainActor
    func updateOutputs(at loopIndex: Int,
                       node: NodeViewModel,
                       portValues: PortValues) {
        let nodeId = node.id
        var outputsToUpdate = node.outputs
        var nodeIdsToRecalculate = NodeIdSet()
        
        for (portId, newOutputValue) in portValues.enumerated() {
            let outputCoordinate = OutputCoordinate(portId: portId, nodeId: nodeId)
            var outputValuesToUpdate: PortValues = outputsToUpdate[safe: portId] ?? []
            
            // Lengthen outputs if loop index exceeds count
            if outputValuesToUpdate.count < loopIndex + 1 {
                outputValuesToUpdate = outputValuesToUpdate.lengthenArray(loopIndex + 1)
            }
            
            // If we can't find the old value at this loop index, assume the output changed
            var outputsChanged: Bool = outputValuesToUpdate[safe: loopIndex].map { $0 != newOutputValue } ?? true
            
            // Insert new output value at correct loop index
            outputValuesToUpdate[loopIndex] = newOutputValue
            
            // Update output state
            var outputToUpdate = outputsToUpdate[portId]
            outputToUpdate = outputValuesToUpdate
            
            outputsToUpdate[portId] = outputToUpdate
            
            // Update downstream node's inputs
            let changedInputIds = self.updateDownstreamInputs(
                sourceNode: node,
                flowValues: outputToUpdate,
                upstreamOutputChanged: outputsChanged,
                outputCoordinate: outputCoordinate)
            let changedNodeIds = Set(changedInputIds.map(\.nodeId)).toSet
            
            nodeIdsToRecalculate = nodeIdsToRecalculate.union(changedNodeIds)
        } // (portId, newOutputValue) in portValues.enumerated()
     
        node.updateOutputsObservers(newValuesList: outputsToUpdate)
        
        // Recalculate graph
        self.scheduleForNextGraphStep(nodeIdsToRecalculate)
    }
}

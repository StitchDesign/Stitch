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
    
    // Populated by `OutputNodeRowObserver.didValuesUpdate` during graph eval on GraphStep N,
    // handled (and wiped) after graph eval has been completed on GraphStep N.
    @MainActor var pulsedOutputs: Set<NodeIOCoordinate> = .init()
    
    let saveLocation: [UUID]
    
    @MainActor var id = GraphId()
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
    
    @MainActor var visibleCanvasNodes: [CanvasItemViewModel] = .init()
    
    // Set true / non-nil in methods or action handlers
    // Set false / nil in StitchUIScrollView
    // TODO: combine canvasZoomedIn and canvasZoomedOut? can never have both at same time? or we can, and they cancel each other?
    @MainActor var canvasZoomedIn: GraphManualZoom = .noZoom
    @MainActor var canvasZoomedOut: GraphManualZoom = .noZoom
    @MainActor var canvasJumpLocation: CGPoint? = nil
    @MainActor var canvasPageOffsetChanged: CGPoint? = nil
    @MainActor var canvasPageZoomScaleChanged: CGFloat? = nil
    
    // Only for node cursor selection box done when shift held
    @MainActor var nodesAlreadySelectedAtStartOfShiftNodeCursorBoxDrag: CanvasItemIdSet? = nil
    
    let propertySidebar = PropertySidebarObserver()
    
    @MainActor
    var edgeEditingState: EdgeEditingState?
    
    @MainActor var edgeAnimationEnabled: Bool = false
    
    @MainActor var activelyEditedCommentBoxTitle: CommentBoxId?

    @MainActor var commentBoxBoundsDict = CommentBoxBoundsDict()

    // Note: our device-screen reading logic uses `.local` coordinate space and so does not detect that items in the graph actually sit a little lower on the screen.
    // TODO: better?: just always look at `.global`
    @MainActor var graphYPosition: CGFloat = .zero
    
    @MainActor var selection = GraphUISelectionState()

    @MainActor var activeDragInteraction = ActiveDragInteractionNodeVelocityData()
    
    // Tracks labels for group ports for perf
    @MainActor var groupPortLabels = [Coordinate : String]()
    
    // Visual edge data
    @MainActor var connectedEdges = [ConnectedEdgeData]()
    
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
        self.id = .init(schema.id)
        self.name = schema.name
        self.layersSidebarViewModel = .init()
        self.topologicalData = .init()
        self.commentBoxesDict.sync(from: schema.commentBoxes)
        self.components = components
        
        // Sync nodes and cached data
        self.syncNodes(nodesDict: nodes)
        
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
                     encoder: (any DocumentEncodable)) {
//        guard let decodedFiles = await encoder.getDecodedFiles() else {
        guard let decodedFiles = encoder.getDecodedFiles() else {
            fatalErrorIfDebug()
            self.init()
            return
        }
        
        let components =  decodedFiles.components.createComponentsDict(parentGraph: nil)
        
        var nodes = NodesViewModelDict()
        for nodeEntity in schema.nodes {
            let newNode = NodeViewModel(from: nodeEntity,
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

        // Splitter data
        var allGroupIds: [NodeId?] = self.nodes.values
            .compactMap { node in
                if node.kind.isGroup {
                    return node.id
                }
                
                return nil
            }
        
        // add nil case
        allGroupIds.append(nil)
        
        self.visibleNodesViewModel
            .visibleSplitterInputRows = allGroupIds.reduce(into: .init()) { result, groupId in
                let inputs = self.visibleNodesViewModel.getSplitterInputRowObservers(for: groupId)
                result.updateValue(inputs, forKey: groupId)
            }
        self.visibleNodesViewModel
            .visibleSplitterOutputRows = allGroupIds.reduce(into: .init()) { result, groupId in
                let outputs = self.visibleNodesViewModel.getSplitterOutputRowObservers(for: groupId)
                result.updateValue(outputs, forKey: groupId)
            }
        
        self.visibleNodesViewModel.updateNodesPagingDict(
            documentZoomData: document.graphMovement.zoomData,
            documentFrame: document.frame)
        
        self.visibleNodesViewModel.updateNodeRowObserversUpstreamAndDownstreamReferences()
        self.visibleNodesViewModel.syncRowViewModels(activeIndex: document.activeIndex)
        
        /// Updates port colors and port colors' cached data (connected-canvas-items)
        self.visibleNodesViewModel.nodes.values.forEach { node in
            // Update cache first:
            node.updateObserversConnectedItemsCache()
            // Then calculate port colors:
            node.updateObserversPortColorsAndConnectedItemsPortColors(
                selectedEdges: self.selectedEdges,
                drawingObserver: self.edgeDrawingObserver)
        }
        
        
        // Update edges after everything else
        let newEdges = self.getVisualEdgeData(groupNodeFocused: document.groupNodeFocused?.groupNodeId)

        // HOT FIX: when we reapply llm-actions, the old and new connected edges are equal per ConnectedEdge's == implementation,
        // so we don't re-render GraphConnectedEdgesView even though the input row view model's port color changed.
        // TODO: why is non-AI-augmentation mode okay here? This is the only place we change graph.connectedEdges, so `getVisualEdgeData` must be producing something different?
        if document.llmRecording.mode == .augmentation {
            self.connectedEdges = newEdges
        } else {
            if self.connectedEdges != newEdges {
                self.connectedEdges = newEdges
            }
        }

        // Update labels for group nodes
        let newGroupLabels = self.getGroupPortLabels()
        if self.groupPortLabels != newGroupLabels {
            self.groupPortLabels = newGroupLabels
        }
        
        // Update visible canvas items
        self.visibleCanvasNodes = self.getCanvasItemsAtTraversalLevel(groupNodeFocused: document.groupNodeFocused?.groupNodeId)
        
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
    var storeDelegate: StitchStore? {
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
    var nodesDict: NodesViewModelDict {
        self.nodes
    }

    @MainActor
    func getMediaUrl(forKey key: MediaKey) -> URL? {
        self.mediaLibrary.get(key)
    }
    
    @MainActor var multiselectInputs: Set<LayerInputPort>? {
        self.propertySidebar.inputsCommonToSelectedLayers
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
    
    @MainActor
    func updateGraphData(_ document: StitchDocumentViewModel) {
        // TODO: What's the difference between a document's documentEncoder and a graph's documentEncoderDelegate?
        guard let documentEncoder = self.documentEncoderDelegate else {
            // TODO: `createTestFriendlyDocument` sets an encoder on both document and graph, but by the time the test runs it gets wiped some how? For now we use
            fatalErrorIfDebug()
            return
        }
        
        self._updateGraphData(document, documentEncoder: documentEncoder)
    }
    
    /// Syncs visible nodes and topological data when persistence actions take place.
    @MainActor
    private func _updateGraphData(_ document: StitchDocumentViewModel,
                                  documentEncoder: any DocumentEncodable) {
        // Update parent graphs first if this graph is a component
        // Order here needed so parent components know if there are input/output changes
        if let parentGraph = self.parentGraph {
            // Note: parent and child graphs always belong to same document
            parentGraph._updateGraphData(document,
                                         documentEncoder: documentEncoder)
        }
                
        // Update position data in case focused group node changed
        if let nodePageData = self.visibleNodesViewModel.nodePageDataAtThisTraversalLevel(document.groupNodeFocused?.groupNodeId) {
            
            if self.canvasPageOffsetChanged != nodePageData.localPosition {
                self.canvasPageOffsetChanged = nodePageData.localPosition
            }
            
            if self.canvasPageZoomScaleChanged != nodePageData.zoomData {
                self.canvasPageZoomScaleChanged = nodePageData.zoomData
            }
        }
                
        // TODO: really, this only makes sense to do for the current visible-graph; how do we know we aren't calling `updateGraphData` from within a nested graph (non-visible) component?
        document.updateVisibleCanvasItems()
        
        self.initializeDelegate(document: document,
                                documentEncoderDelegate: documentEncoder)
        
        // TODO: `document.updateVisibleCanvasItems()` updates the cache of "which canvas items are visible in the view port?", so why do we then immediately reset that cache down here? Do we need it for the portLocation updates?
        // Updates node visibility data
        // Set all nodes visible so that input/output fields' UI update if we enter a new traversal level
        self.visibleNodesViewModel.resetVisibleCanvasItemsCache()
    }
        
    @MainActor
    func getVisualEdgeData(groupNodeFocused: NodeId?) -> [ConnectedEdgeData] {
        let canvasItemsAtThisTraversalLevel = self
            .getCanvasItemsAtTraversalLevel(groupNodeFocused: groupNodeFocused)
        
        let newInputs = canvasItemsAtThisTraversalLevel
            .flatMap { canvasItem -> [InputNodeRowViewModel] in
                canvasItem.inputViewModels
            }
        
        
        let connectedInputs = newInputs.filter { input in
            guard input.nodeDelegate?.patchNodeViewModel?.patch != .wirelessReceiver else {
                return false
            }
            return input.rowDelegate?.containsUpstreamConnection ?? false
        }
        
        return connectedInputs.compactMap { connection in
            ConnectedEdgeData(downstreamRowObserver: connection)
        }
    }
}

extension GraphState {
    var sidebarSelectionState: LayersSidebarViewModel.SidebarSelectionState {
        self.layersSidebarViewModel.selectionState
    }
    
    @MainActor func createSchema(from graph: GraphState) -> GraphEntity {
        self.createSchema()
    }
    
    @MainActor
    func createSchema() -> GraphEntity {
        let nodes = self.visibleNodesViewModel.nodes.values
            .map { $0.createSchema() }
        let commentBoxes = self.commentBoxesDict.values.map { $0.createSchema() }
        
        let graph = GraphEntity(id: self.projectId.value,
                                name: self.name,
                                nodes: nodes,
                                orderedSidebarLayers: self.layersSidebarViewModel.createdOrderedEncodedData(),
                                commentBoxes: commentBoxes)
        return graph
    }
    
    @MainActor
    func syncNodes(with entities: [NodeEntity]) {
        let currentEntities = self.createSchema().nodes
        
        guard currentEntities != entities else {
            return
        }
        
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
        
        self.syncNodes(nodesDict: newDictionary)
    }
    
    @MainActor
    func syncNodes(nodesDict: NodesViewModelDict) {
        self.visibleNodesViewModel.nodes = nodesDict
        self.updateLayerDropdownChoiceCache()
    }
    
    @MainActor
    func updateLayerDropdownChoiceCache() {
        // Cache layer node info for perf
        let newLayerCache = nodesDict.values.reduce(into: [NodeId : LayerDropdownChoice]()) { result, node in
            if node.kind.isLayer {
                result.updateValue(node.asLayerDropdownChoice, forKey: node.id)
            }
        }
        
        if self.visibleNodesViewModel.layerDropdownChoiceCache != newLayerCache {
            self.visibleNodesViewModel.layerDropdownChoiceCache = newLayerCache
        }
    }
    
    @MainActor
    private func updateSynchronousProperties(from schema: GraphEntity) {
        assertInDebug(self.id.value == schema.id)
        
        if self.name != schema.name {
            self.name = schema.name
        }
        
        self.layersSidebarViewModel.update(from: schema.orderedSidebarLayers)
    }
    
    @MainActor func update(from schema: GraphEntity, rootUrl: URL?) {
        self.updateSynchronousProperties(from: schema)
        
        // If we're not in a test context (closest proxy = simulator),
        // rootUrl should be non-nil.
        // TODO: `rootUrl` is currently nil in a test context; can we find a smarter way to handle the projectLoader/documentEncoder ?
        #if !targetEnvironment(simulator)
        assertInDebug(rootUrl.isDefined)
        #endif
        if let rootUrl = rootUrl,
           let decodedFiles = DocumentEncoder.getDecodedFiles(rootUrl: rootUrl) {
            self.importedFilesDirectoryReceived(mediaFiles: decodedFiles.mediaFiles,
                                                components: decodedFiles.components)
        }
        
        self.syncNodes(with: schema.nodes)
        
        // Determines if graph data needs updating
        self.documentDelegate?.refreshGraphUpdaterId()
    }
    
    @MainActor
    func update(from entity: GraphEntity) {
        self.update(from: entity,
                    // TODO: 'updating view models according to schema' should not require that we have a document encoder; in certain contexts (e.g. tests) we won't have a project loader
                    rootUrl: self.documentEncoderDelegate?.rootUrl)
    }
    
    @MainActor func onPrototypeRestart(document: StitchDocumentViewModel) {
        self.nodes.values.forEach { $0.onPrototypeRestart(document: document) }
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
    func getOutputRowObserver(_ id: NodeIOCoordinate) -> OutputNodeRowObserver? {
        self.getNodeViewModel(id.nodeId)?.getOutputRowObserver(for: id.portType)
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
    func getBroadcasterNodesAtThisTraversalLevel(document: StitchDocumentViewModel) -> [NodeViewModel] {
        self.visibleNodesViewModel.getNodesAtThisTraversalLevel(at: document.groupNodeFocused?.groupNodeId)
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
    
    @MainActor func getGroupPortLabels() -> [Coordinate : String] {
        self.nodes.values.reduce(into: [Coordinate : String]()) { result, node in
            guard let patchNode = node.patchNodeViewModel,
                  let splitterNode = patchNode.splitterNode else {
                return
            }
            
            let title = node.displayTitle
                        
            if splitterNode.type == .input,
               let input = patchNode.inputsObservers.first {
                result.updateValue(title, forKey: .input(input.id))
            }
            
            else if splitterNode.type == .output,
                    let output = patchNode.outputsObservers.first {
                result.updateValue(title, forKey: .output(output.id))
            }
        }
    }
    
    @MainActor
    func encodeProjectInBackground(temporaryURL: URL? = nil,
                                   willUpdateUndoHistory: Bool = true) {
        guard let store = self.storeDelegate,
              let documentEncoder = self.documentEncoderDelegate else {
            // fatalErrorIfDebug()
            log("encodeProjectInBackground: missing store and/or decoder delegates")
            return
        }
        
        documentEncoder.encodeProjectInBackground(from: self,
                                                  temporaryUrl: temporaryURL,
                                                  willUpdateUndoHistory: willUpdateUndoHistory,
                                                  store: store)
        
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
        guard let store = self.storeDelegate,
              let documentEncoder = self.documentEncoderDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        documentEncoder.encodeProjectInBackground(from: self,
                                                  undoEvents: undoEvents,
                                                  temporaryUrl: temporaryURL,
                                                  willUpdateUndoHistory: willUpdateUndoHistory,
                                                  store: store)
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
    func getNodesAtThisTraversalLevel(groupNodeFocused: NodeId?) -> [NodeViewModel] {
        self.visibleNodesViewModel
            .getNodesAtThisTraversalLevel(at: groupNodeFocused)
    }
    
    @MainActor
    func getCanvasItemsAtTraversalLevel(groupNodeFocused: NodeId?) -> CanvasItemViewModels {
        self.visibleNodesViewModel
            .getCanvasItemsAtTraversalLevel(at: groupNodeFocused)
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
                       portValues: PortValues,
                       media: GraphMediaValue?) {
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
            let outputsChanged: Bool = outputValuesToUpdate[safe: loopIndex].map { $0 != newOutputValue } ?? true
            
            // Insert new output value at correct loop index
            outputValuesToUpdate[loopIndex] = newOutputValue
            
            // Update output state
            var outputToUpdate = outputsToUpdate[portId]
            outputToUpdate = outputValuesToUpdate
            
            outputsToUpdate[portId] = outputToUpdate
            
            let mediaList: [GraphMediaValue?]? = media == nil ? nil : [media]
            
            // Update downstream node's inputs
            let changedInputIds = self.updateDownstreamInputs(
                sourceNode: node,
                upstreamOutputValues: outputToUpdate,
                mediaList: mediaList,
                upstreamOutputChanged: outputsChanged,
                outputCoordinate: outputCoordinate)
            let changedNodeIds = Set(changedInputIds.map(\.nodeId)).toSet
            
            nodeIdsToRecalculate = nodeIdsToRecalculate.union(changedNodeIds)
        } // (portId, newOutputValue) in portValues.enumerated()
     
        node.updateOutputsObservers(newValuesList: outputsToUpdate, graph: self)
        
        // Recalculate graph
        self.scheduleForNextGraphStep(nodeIdsToRecalculate)
    }
}

//
//  State.swift
//  prototype
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


let STITCH_PROJECT_DEFAULT_NAME = StitchDocument.defaultName

// TODO: put in separate file called `GraphStateExtensions.swift` ?
extension StitchDocumentViewModel: Hashable {
    static func == (lhs: StitchDocumentViewModel, rhs: StitchDocumentViewModel) -> Bool {
        lhs.graph.id == rhs.graph.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.graph.id)
    }
}

// TODO: move
@Observable
final class StitchDocumentViewModel: Sendable {
    let graph: GraphState
    @MainActor let graphUI: GraphUIState
    let graphStepManager = GraphStepManager()
    let graphMovement = GraphMovementObserver()
    
    // Updated when connections, new nodes etc change
    var topologicalData = GraphTopologicalData<NodeViewModel>()
    
    let previewWindowSizingObserver = PreviewWindowSizing()
    
    // Cache of ordered list of preview layer view models;
    // updated in various scenarious, e.g. sidebar list item dragged
    var cachedOrderedPreviewLayers: LayerDataList = .init()
    
    // Updates to true if a layer's input should re-sort preview layers (z-index, masks etc)
    // Checked at the end of graph calc for efficient updating
    var shouldResortPreviewLayers: Bool = false
    
    // Keeps track of interaction nodes and their selected layer
    var dragInteractionNodes = [LayerNodeId: NodeIdSet]()
    var pressInteractionNodes = [LayerNodeId: NodeIdSet]()
    var scrollInteractionNodes = [LayerNodeId: NodeIdSet]()
    
    // Used in rotation modifier to know whether view receives a pin;
    // updated whenever preview layers cache is updated.
    var pinMap = RootPinMap()
    var flattenedPinMap = PinMap()
    
    var isGeneratingProjectThumbnail = false
    
    // The raw size we pass to GeneratePreview
    var previewWindowSize: CGSize = PreviewWindowDevice.DEFAULT_PREVIEW_SIZE
    
    // Changed by e.g. project-settings modal, e.g. UpdatePreviewCanvasDevice;
    // Not changed by user's manual drag on the preview window handle.
    var previewSizeDevice: PreviewWindowDevice = PreviewWindowDevice.DEFAULT_PREVIEW_OPTION
    
    var previewWindowBackgroundColor: Color = DEFAULT_FLOATING_WINDOW_COLOR
    
    var cameraSettings = CameraSettings()
    
    var keypressState = KeyPressState()
    var llmRecording = LLMRecordingState()
    
    // Singleton instances
    var locationManager: LoadingStatus<StitchSingletonMediaObject>?
    var cameraFeedManager: LoadingStatus<StitchSingletonMediaObject>?
    
    // Keeps reference to store
    weak var storeDelegate: StoreDelegate?
    
    @MainActor init(from schema: StitchDocument,
                    store: StoreDelegate?) {
        // MARK: do not populate ordered sidebar layers until effect below is dispatched!
        // This is to help GeneratePreview render correctly, which uses ordered sidebar layers to render
        // but nodes haven't yet populated
        self.graphUI = GraphUIState()
        self.previewWindowSize = schema.previewWindowSize
        self.previewSizeDevice = schema.previewSizeDevice
        self.previewWindowBackgroundColor = schema.previewWindowBackgroundColor
        self.cameraSettings = schema.cameraSettings
        self.graphMovement.localPosition = schema.localPosition
        self.graph = .init(from: schema)
        
        self.graphStepManager.delegate = self
        self.storeDelegate = store
        self.graph.initializeDelegate(document: self)
    }
}

extension StitchDocumentViewModel {
    var id: UUID {
        self.graph.id
    }
    
    var projectId: UUID {
        self.id
    }
    
    var projectName: String {
        self.graph.name
    }
    
    // TODO: fix visible graph state to use graphUI selection
    var visibleGraph: GraphState {
        self.graph
    }
    
    // TODO: update with components
    var allGraphs: [GraphState] {
        [self.graph]
    }
    
    var activeIndex: ActiveIndex {
        self.graphUI.activeIndex
    }
    
    @MainActor var graphStepState: GraphStepState {
        self.graphStepManager.graphStepState
    }
    
    /// Syncs visible nodes and topological data when persistence actions take place.
    @MainActor
    func updateGraphData(document: StitchDocument? = nil) {
        let document = document ?? self.createSchema()

        self.allGraphs.forEach {
            // TODO: update visible nodes updater for specific nodes
            $0.visibleNodesViewModel.updateSchemaData(newNodes: document.nodes,
                                                      activeIndex: self.activeIndex,
                                                      graphDelegate: $0)
        }
        
        self.updateTopologicalData()

        // MARK: must be called after connections are established in both visible nodes and topolological data
        self.allGraphs.forEach {
            $0.visibleNodesViewModel.updateAllNodeViewData()
        }
        
        // Update preview layers
        self.updateOrderedPreviewLayers()
    }
    
    var cameraFeed: CameraFeedManager? {
        self.cameraFeedManager?.loadedInstance?.cameraFeedManager
    }

}

extension StitchDocumentViewModel: GraphCalculatable {
    
    var orderedSidebarLayers: SidebarLayerList {
        self.graph.orderedSidebarLayers
    }
    
    @MainActor
    func updateOrderedPreviewLayers() {
        // Cannot use Equality check here since LayerData does not conform to Equatable;
        // so instead we should be smart about only calling this when layer nodes actually change.
        
        let flattenedPinMap = self.getFlattenedPinMap()
        let rootPinMap = self.getRootPinMap(pinMap: flattenedPinMap)
        
        let previewLayers = self.recursivePreviewLayers(sidebarLayersGlobal: self.orderedSidebarLayers,
                                                        pinMap: rootPinMap)
        
        self.cachedOrderedPreviewLayers = previewLayers
        self.flattenedPinMap = flattenedPinMap
        self.pinMap = rootPinMap
    }
    
    func getNodesToAlwaysRun() -> Set<UUID> {
        Array(self.nodes
                .values
                .filter { $0.patch?.willAlwaysRunEval ?? false }
                .map(\.id))
            .toSet
    }
    
    func getAnimationNodes() -> Set<UUID> {
        Array(self.nodes
                .values
                .filter { $0.patch?.isAnimationNode ?? false }
                .map(\.id))
            .toSet
    }
    
    var nodes: [UUID : NodeViewModel] {
        get {
            self.graph.nodes
        }
        set(newValue) {
            self.graph.nodes = newValue
        }
    }
    
    func getNodeViewModel(_ id: UUID) -> NodeViewModel? {
        self.graph.getNodeViewModel(id)
    }
    
    func getNodeViewModel(id: UUID) -> NodeViewModel? {
        self.getNodeViewModel(id)
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func update(from schema: StitchDocument) {
        // Sync preview window attributes
        self.previewWindowSize = schema.previewWindowSize
        self.previewSizeDevice = schema.previewSizeDevice
        self.previewWindowBackgroundColor = schema.previewWindowBackgroundColor

        // Sync node view models + cached data
        self.graph.update(from: schema)
        self.updateGraphData(document: schema)
        
        // No longer needed, since sidebar-expanded-items handled by node schema
//        self.sidebarExpandedItems = self.allGroupLayerNodes()
        self.calculateFullGraph()
    }
    
    @MainActor func createSchema() -> StitchDocument {
        self.graph.createSchema()
    }
    
    @MainActor func onPrototypeRestart() {
        self.graphStepManager.resetGraphStepState()
        
        self.graph.onPrototypeRestart()
        
        // Defocus the preview window's TextField layer
        if self.graphUI.reduxFocusedField?.getTextFieldLayerInputEdit.isDefined ?? false {
            self.graphUI.reduxFocusedField = nil
        }
        
        // Update animation value for restart-prototype icon;
        self.graphUI.restartPrototypeWindowIconRotationZ += 360

        self.initializeGraphComputation()
    }
}

@Observable
final class GraphState: Sendable {
    
    // TODO: wrap in a new data structure like `SidebarUIState`
    var sidebarListState: SidebarListState = .init()
    var sidebarSelectionState = SidebarSelectionState()
    
    // Should be added to StitchDocument, since we remember which groups are open vs collapsed.
    //    var sidebarExpandedItems = LayerIdSet() // should be persisted
    
    let documentEncoder: DocumentEncoder

    var id = UUID()
    var name: String = STITCH_PROJECT_DEFAULT_NAME
    
    var commentBoxesDict = CommentBoxesDict()

    let visibleNodesViewModel = VisibleNodesViewModel()
    let edgeDrawingObserver = EdgeDrawingObserver()

    // Loading status for media
    var libraryLoadingStatus = LoadingState.loading

    var selectedEdges = Set<PortEdgeUI>()

    // Hackiness for handling edge case in our UI where somehow
    // UIKit node drag and SwiftUI port drag can happen at sometime.
    var nodeIsMoving = false
    var outputDragStartedCount = 0

    // Ordered list of layers in sidebar
    var orderedSidebarLayers: SidebarLayerList = []

    // Maps a MediaKey to some URL
    var mediaLibrary: MediaLibrary = [:]

    // DEVICE MOTION
    var motionManagers = StitchMotionManagersDict()
    
    var networkRequestCompletedTimes = NetworkRequestLatestCompletedTimeDict()
    
    weak var documentDelegate: StitchDocumentViewModel?

    init(from schema: StitchDocument) {
        self.documentEncoder = .init(document: schema)
        self.id = schema.id
        self.name = schema.name
        self.commentBoxesDict.sync(from: schema.commentBoxes)

        // MARK: important we don't initialize nodes until after media is estbalished
        DispatchQueue.main.async { [weak self] in
            if let graph = self {
                dispatch(GraphInitialized(graph: graph,
                                          document: schema))
            }
        }
    }
    
    func initializeDelegate(document: StitchDocumentViewModel) {
        self.documentDelegate = document
    }
}

extension GraphState: GraphDelegate {
    @MainActor var graphUI: GraphUIState {
        guard let graphUI = self.documentDelegate?.graphUI else {
            fatalErrorIfDebug()
            return GraphUIState()
        }
        
        return graphUI
    }
    
    var storeDelegate: StoreDelegate? {
        self.documentDelegate?.storeDelegate
    }
    
    var nodes: [UUID : NodeViewModel] {
        get {
            self.visibleNodesViewModel.nodes
        }
        set(newValue) {
            self.visibleNodesViewModel.nodes = newValue
        }
    }
    
    var groupNodeFocused: NodeId? {
        self.graphUI.groupNodeFocused?.asNodeId
    }
    
    var nodesDict: NodesViewModelDict {
        self.nodes
    }

    var safeAreaInsets: SafeAreaInsets {
        self.graphUI.safeAreaInsets
    }
    
    var isFullScreenMode: Bool {
        self.graphUI.isFullScreenMode
    }
    
    func getMediaUrl(forKey key: MediaKey) -> URL? {
        self.mediaLibrary.get(key)
    }
    
    @MainActor var multiselectInputs: LayerInputTypeSet? {
        self.graphUI.propertySidebar.inputsCommonToSelectedLayers
    }
}

extension StitchDocumentViewModel {
    @MainActor convenience init(id: ProjectId,
                                projectName: String = STITCH_PROJECT_DEFAULT_NAME,
                                previewWindowSize: CGSize = PreviewWindowDevice.DEFAULT_PREVIEW_SIZE,
                                previewSizeDevice: PreviewWindowDevice = PreviewWindowDevice.DEFAULT_PREVIEW_OPTION,
                                previewWindowBackgroundColor: Color = DEFAULT_FLOATING_WINDOW_COLOR,
                                localPosition: CGPoint = .zero,
                                zoomData: CGFloat = 1,
                                nodes: [NodeEntity] = [],
                                orderedSidebarLayers: [SidebarLayerData] = [],
                                commentBoxes: [CommentBoxData] = .init(),
                                cameraSettings: CameraSettings = CameraSettings(),
                                store: StoreDelegate?) {
        let document = StitchDocument(projectId: id,
                                      name: projectName,
                                      previewWindowSize: previewWindowSize,
                                      previewSizeDevice: previewSizeDevice,
                                      previewWindowBackgroundColor: previewWindowBackgroundColor,
                                      localPosition: localPosition,
                                      zoomData: zoomData,
                                      nodes: nodes,
                                      orderedSidebarLayers: orderedSidebarLayers,
                                      commentBoxes: commentBoxes,
                                      cameraSettings: cameraSettings)
        self.init(from: document, store: store)
    }
}

extension GraphState {
    @MainActor
    func update(from schema: StitchDocument) {
        // Sync project attributes
        self.id = schema.projectId
        self.name = schema.name
        self.orderedSidebarLayers = schema.orderedSidebarLayers
    }

    @MainActor func createSchema() -> StitchDocument {
        assertInDebug(self.documentDelegate != nil)
        let documentDelegate = self.documentDelegate ?? .init(from: .init(),
                                                              store: self.storeDelegate)
        
        let nodes = self.visibleNodesViewModel.nodes.values
            .map { $0.createSchema() }
        let commentBoxes = self.commentBoxesDict.values.map { $0.createSchema() }

        return StitchDocument(projectId: self.projectId,
                              name: documentDelegate.projectName,
                              previewWindowSize: documentDelegate.previewWindowSize,
                              previewSizeDevice: documentDelegate.previewSizeDevice,
                              previewWindowBackgroundColor: self.previewWindowBackgroundColor,
                              // Important: `StitchDocument.localPosition` currently represents only the root level's graph-offset
                              localPosition: documentDelegate.localPositionToPersist,
                              zoomData: self.graphMovement.zoomData.zoom,
                              nodes: nodes,
                              orderedSidebarLayers: self.orderedSidebarLayers,
                              commentBoxes: commentBoxes,
                              cameraSettings: documentDelegate.cameraSettings)
    }
    
    @MainActor func onPrototypeRestart() {
        self.nodes.values.forEach { $0.onPrototypeRestart() }
    }
    
    var localPosition: CGPoint {
        self.documentDelegate?.localPosition ?? .init()
    }
    
    var previewWindowBackgroundColor: Color {
        self.documentDelegate?.previewWindowBackgroundColor ?? .LAYER_DEFAULT_COLOR
    }
}

extension GraphState {
    @MainActor func updateTopologicalData() {
        self.documentDelegate?.updateTopologicalData()
    }
    
    var mouseNodes: NodeIdSet {
        self.documentDelegate?.mouseNodes ?? .init()
    }
    
    @MainActor
    func getInputRowObserver(_ id: NodeIOCoordinate) -> InputNodeRowObserver? {
        self.getNodeViewModel(id.nodeId)?.getInputRowObserver(for: id.portType)
    }
    
    @MainActor
    var activeIndex: ActiveIndex {
        self.graphUI.activeIndex
    }
    
    var llmRecording: LLMRecordingState {
        self.documentDelegate?.llmRecording ?? .init()
    }
    
    @MainActor
    func updateOrderedPreviewLayers() {
        self.documentDelegate?.updateOrderedPreviewLayers()
    }
    
    var graphStepManager: GraphStepManager {
        guard let document = self.documentDelegate else {
            fatalErrorIfDebug()
            return .init()
        }
        
        return document.graphStepManager
    }
    
    @MainActor
    func getBroadcasterNodesAtThisTraversalLevel() -> [NodeDelegate] {
        self.visibleNodesViewModel.getVisibleNodes(at: self.graphUI.groupNodeFocused?.asNodeId)
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
    
    @MainActor
    func encodeProjectInBackground(temporaryURL: DocumentsURL? = nil) {
        guard let documentLoader = self.storeDelegate?.documentLoader else {
            fatalErrorIfDebug()
            return
        }
        
        let document = self.createSchema()
        
        Task(priority: .background) { [weak documentLoader, weak self] in
            guard let documentLoader = documentLoader else {
                fatalErrorIfDebug()
                return
            }
            
            let _ = await self?.documentEncoder.encodeProject(document, temporaryURL: temporaryURL,
                                                              documentLoader: documentLoader)
        }
    }
    
    @MainActor
    func encodeProject(temporaryURL: DocumentsURL? = nil) {
        let document = self.createSchema()
        
        // Update nodes data
        self.updateGraphData(document: document)
        
        Task(priority: .background) { [weak self] in
            guard let documentLoader = self?.storeDelegate?.documentLoader else {
                return
            }
            
            switch await self?.documentEncoder.encodeProject(document,
                                                             temporaryURL: temporaryURL,
                                                             documentLoader: documentLoader) {
            case .success, .none:
                return
            case .failure(let error):
                log("GraphState.encodeProject error: \(error)")
            }
        }
    }
    
    func getPatchNode(id nodeId: NodeId) -> PatchNode? {
        self.visibleNodesViewModel.patchNodes.get(nodeId)
    }
    
    var patchNodes: NodesViewModelDict {
        self.visibleNodesViewModel.patchNodes
    }
    
    var layerNodes: NodesViewModelDict {
        self.visibleNodesViewModel.layerNodes
    }
    
    var groupNodes: NodesViewModelDict {
        self.visibleNodesViewModel.groupNodes
    }
    
    /*
     Primarily used for NodeViewModels, which are used in UI and during graph eval
     
     Secondarily used in some helpers for creating a GraphState that we then feed into GraphSchema
     - second use-case ideally removed in the future
     */
    func updateNode(_ node: NodeViewModel) {
        self.visibleNodesViewModel.nodes
            .updateValue(node, forKey: node.id)
    }
    
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
        }
    }
    
    func getLayerNode(id: NodeId) -> NodeViewModel? {
        self.getNodeViewModel(id)
    }
    
    // id = NodeId for GroupNode
    func getGroupNode(id: GroupNodeId) -> NodeViewModel? {
        self.getNodeViewModel(id.asNodeId)
    }
    
    func getGroupNodeBreadcrumb(id: GroupNodeId) -> NodeId? {
        getGroupNode(id: id)?.id
    }
    
    @MainActor
    func getVisibleNodes() -> [NodeDelegate] {
        self.visibleNodesViewModel
            .getVisibleNodes(at: self.graphUI.groupNodeFocused?.asNodeId)
    }
    
    @MainActor
    func getVisibleCanvasItems() -> CanvasItemViewModels {
        self.visibleNodesViewModel
            .getVisibleCanvasItems(at: self.graphUI.groupNodeFocused?.asNodeId)
    }
    
    @MainActor
    func getCanvasItems() -> CanvasItemViewModels {
        self.visibleNodesViewModel.getCanvasItems()
    }
    
    var keyboardNodes: NodeIdSet {
        Array(self.nodes
            .values
            .filter { $0.patch == .keyboard }
            .map(\.id))
        .toSet
    }
    
    func getLayerChildren(for groupId: NodeId) -> NodeIdSet {
        self.nodes.values
            .filter { $0.layerNode?.layerGroupId == groupId }
            .map { $0.id }
            .toSet
    }
    
    @MainActor
    func getGroupChildren(for groupId: NodeId) -> NodeIdSet {
        self.nodes.values
            .flatMap { $0.getAllCanvasObservers() }
            .filter { $0.parentGroupNodeId == groupId }
            .compactMap { $0.nodeDelegate?.id }
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
}

extension StitchDocumentViewModel {
    /// Updates values at a specific output loop index.
    @MainActor
    func updateOutputs(at loopIndex: Int,
                       node: NodeViewModel,
                       portValues: PortValues) {
        let nodeId = node.id
        var outputsToUpdate = node.outputs
        var nodeIdsToRecalculate = NodeIdSet()
        let graphTime = self.graphStepManager.graphTime
        
        for (portId, newOutputValue) in portValues.enumerated() {
            let outputCoordinate = OutputCoordinate(portId: portId, nodeId: nodeId)
            var outputValuesToUpdate = outputsToUpdate[safe: portId] ?? []
            
            // Lengthen outputs if loop index exceeds count
            if outputValuesToUpdate.count < loopIndex + 1 {
                outputValuesToUpdate = outputValuesToUpdate.lengthenArray(loopIndex + 1)
            }
            
            // Insert new output value at correct loop index
            outputValuesToUpdate[loopIndex] = newOutputValue
            
            // Update output state
            var outputToUpdate = outputsToUpdate[portId]
            outputToUpdate = outputValuesToUpdate
            
            outputsToUpdate[portId] = outputToUpdate
            
            // Update downstream node's inputs
            let changedNodeIds = self.updateDownstreamInputs(
                flowValues: outputToUpdate,
                outputCoordinate: outputCoordinate)
            
            nodeIdsToRecalculate = nodeIdsToRecalculate.union(changedNodeIds)
        } // (portId, newOutputValue) in portValues.enumerated()
     
        node.updateOutputsObservers(newOutputsValues: outputsToUpdate,
                                    activeIndex: self.activeIndex)
        
        // Must also run pulse reversion effects
        node.outputs
            .getPulseReversionEffects(nodeId: nodeId,
                                      graphTime: graphTime)
            .processEffects()
        
        // Recalculate graph
        self.calculate(nodeIdsToRecalculate)
    }
}

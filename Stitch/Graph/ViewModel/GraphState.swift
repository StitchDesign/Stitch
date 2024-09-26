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

// TODO: move
/// Tracks drafted and persisted versions of components, used to populate copies in graph.
final class StitchMasterComponent {
    @MainActor var componentData: StitchComponentData {
        self.documentEncoder.lastEncodedDocument
    }
    
    let id: UUID
    let saveLocation: GraphSaveLocation
    
    // Encoded copy of drafted component
    let documentEncoder: ComponentEncoder
    
    weak var parentGraph: GraphState?
    
    init(componentData: StitchComponentData,
         parentGraph: GraphState?) {
        self.id = componentData.draft.id
        self.saveLocation = componentData.draft.saveLocation
//        self.componentData = componentData
        self.documentEncoder = .init(component: componentData)
        self.parentGraph = parentGraph
        
//        DispatchQueue.main.async { { [weak self] in
//            guard let component = self else { return }
//            component.documentEncoder.delegate = component
//        }
    }
}

extension StitchMasterComponent {
    @MainActor var publishedComponent: StitchComponent? {
        self.componentData.published
    }
       
    @MainActor var draftedComponent: StitchComponent {
        self.componentData.draft
    }
    
//    func update(from schema: StitchComponentData) {
//        self.componentData = schema
//    }
    
    @MainActor func createSchema() -> StitchComponentData {
        self.componentData
    }
    
    static func createObject(from entity: StitchComponentData) -> Self {
        .init(componentData: entity,
              parentGraph: nil)
    }
    
    func onPrototypeRestart() { }
    
    func initializeDelegate(parentGraph: GraphState) {
        self.parentGraph = parentGraph
        
        Task {
            await MainActor.run { [weak self] in
                guard let component = self else { return }
                component.documentEncoder.delegate = component
            }
        }
    }
}

typealias MasterComponentsDict = [UUID : StitchMasterComponent]

extension StitchMasterComponent: DocumentEncodableDelegate, Identifiable {
    @MainActor func willEncodeProject(schema: StitchComponentData) {
//        self.componentData = schema
        self.parentGraph?.documentEncoderDelegate?.encodeProjectInBackground()
    }
    
//    func importedFilesDirectoryReceived(mediaFiles: [URL],
//                                        components: [StitchComponentData]) {
//        guard let parentGraph = parentGraph else {
//            fatalErrorIfDebug()
//            return
//        }
//        
//        // Find all graph states leveraging this component
//        let componentGraphStates = parentGraph.nodes.values
//            .compactMap { node -> GraphState? in
//                guard let component = node.nodeType.componentNode,
//                component.componentId == self.id else {
//                    return nil
//                }
//                return component.graph
//            }
//        
//        componentGraphStates.forEach { graphState in
//            graphState.importedFilesDirectoryReceived(mediaFiles: mediaFiles,
//                                                      components: components)
//        }
//    }
}

extension StitchDocumentViewModel {
    /// Returns self and all graphs inside component instances.
    var allGraphs: [GraphState] {
        self.graph.allGraphs
    }
    
    @MainActor func calculateAllKeyboardNodes() {
        self.allGraphs.forEach { graph in
            let keyboardNodes = graph.keyboardNodes
            graph.calculate(keyboardNodes)
        }
    }
}

extension GraphState {
    /// Returns self and all graphs inside component instances.
    var allGraphs: [GraphState] {
        [self] + allComponentGraphs
    }
    
    var allComponentGraphs: [GraphState] {
        self.nodes.values.flatMap { node -> [GraphState] in
            guard let nodeComponent = node.nodeType.componentNode else {
                return []
            }
            
            return nodeComponent.graph.allGraphs
        }
    }
    
    /// Finds graph state given a node ID of some component node.
    func findComponentGraphState(_ nodeId: UUID) -> GraphState? {
        for node in self.nodes.values {
            guard let nodeComponent = node.nodeType.componentNode else {
                continue
            }
            
            if nodeComponent.id == nodeId {
                return nodeComponent.graph
            }
            
            // Recursive check--we found a match if path isn't empty
            let recursivePath = nodeComponent.getComponentPath(to: id)
            if let matchedGraph = recursivePath.last?.graph {
                return matchedGraph
            }
        }
        
        return nil
    }
    
    func getComponentPath(_ id: UUID) -> [UUID] {
        for node in self.nodes.values {
            guard let nodeComponent = node.nodeType.componentNode else {
                continue
            }
            
            // Recursive check--we found a match if path isn't empty
            let recursivePath = nodeComponent.getComponentPath(to: id)
            if !recursivePath.isEmpty {
                return recursivePath.map { $0.id }
            }
        }
        
        return []
    }
    
    /// Syncs visible nodes and topological data when persistence actions take place.
    @MainActor
    func updateGraphData() {
        self.updateTopologicalData()

        // Update preview layers
        self.updateOrderedPreviewLayers()
    }
}

extension StitchComponentViewModel {
    /// Recursively checks node component's `GraphState`'s until a match is found.
    func getComponentPath(to id: UUID) -> [StitchComponentViewModel] {
        for node in self.graph.nodes.values {
            guard let nodeComponent = node.nodeType.componentNode else {
                continue
            }
            
            if node.id == id {
                if nodeComponent.componentId == id {
                    return [nodeComponent]
                } else {
                    fatalErrorIfDebug("Node ID should match component ID")
                }
            }
            
            // Recursive check--we found a match if path isn't empty
            let recursivePath = nodeComponent.getComponentPath(to: id)
            if !recursivePath.isEmpty {
                return [self] + recursivePath
            }
        }
        
        return []
    }
}

@Observable
final class GraphState: Sendable {
    // Updated when connections, new nodes etc change
    var topologicalData = GraphTopologicalData<NodeViewModel>()
    
    let saveLocation: [UUID]
    
    // TODO: wrap in a new data structure like `SidebarUIState`
    var sidebarListState: SidebarListState = .init()
    var sidebarSelectionState = SidebarSelectionState()
    
    // Should be added to StitchDocument, since we remember which groups are open vs collapsed.
    //    var sidebarExpandedItems = LayerIdSet() // should be persisted
    
//    let documentEncoder: DocumentEncoder

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
    
    // Keeps track of interaction nodes and their selected layer
    var dragInteractionNodes = [LayerNodeId: NodeIdSet]()
    var pressInteractionNodes = [LayerNodeId: NodeIdSet]()
    var scrollInteractionNodes = [LayerNodeId: NodeIdSet]()

    // Ordered list of layers in sidebar
    var orderedSidebarLayers: SidebarLayerList = []
    
    // Cache of ordered list of preview layer view models;
    // updated in various scenarious, e.g. sidebar list item dragged
    var cachedOrderedPreviewLayers: LayerDataList = .init()
    
    // Updates to true if a layer's input should re-sort preview layers (z-index, masks etc)
    // Checked at the end of graph calc for efficient updating
    var shouldResortPreviewLayers: Bool = false
    
    // Used in rotation modifier to know whether view receives a pin;
    // updated whenever preview layers cache is updated.
    var pinMap = RootPinMap()
    var flattenedPinMap = PinMap()
    
    // Tracks all created and imported components
    var components: [UUID: StitchMasterComponent] = [:]

    // Maps a MediaKey to some URL
    var mediaLibrary: MediaLibrary = [:]

    // DEVICE MOTION
    var motionManagers = StitchMotionManagersDict()
    
    var networkRequestCompletedTimes = NetworkRequestLatestCompletedTimeDict()
    
    weak var documentDelegate: StitchDocumentViewModel?
    weak var documentEncoderDelegate: (any DocumentEncodable)?

    init(from schema: GraphEntity,
         saveLocation: [UUID],
         graphDecodedFiles: GraphDecodedFiles) {
        self.saveLocation = saveLocation
        self.id = schema.id
        self.name = schema.name
        self.commentBoxesDict.sync(from: schema.commentBoxes)
        self.orderedSidebarLayers = schema.orderedSidebarLayers
        
        // Add default URLs
        MediaLibrary.getDefaultLibraryDeps().forEach { url in
            mediaLibrary.updateValue(url, forKey: url.mediaKey)
        }
        
        self.importedFilesDirectoryReceived(mediaFiles: graphDecodedFiles.mediaFiles,
                                             components: graphDecodedFiles.components)
        
//        Task(priority: .high) { [weak self] in
//            guard let graph = self else { return }
//            await graph.visibleNodesViewModel
//                .updateNodeSchemaData(newNodes: schema.nodes,
//                                      components: graph.components,
//                                      parentGraphPath: graph.saveLocation)
            
//            await MainActor.run { [weak self] in
//                guard let graph = self else { return }
//                
//                guard let document = graph.documentDelegate,
//                      let documentEncoder = graph.documentEncoderDelegate else {
//                    fatalErrorIfDebug()
//                    return
//                }
//
//                graph.initializeDelegate(document: document,
//                                         documentEncoderDelegate: documentEncoder)
//                
//                graph.updateSidebarListStateAfterStateChange()
//                
//                // TODO: why is this necessary?
//                _updateStateAfterListChange(
//                    updatedList: graph.sidebarListState,
//                    expanded: graph.getSidebarExpandedItems(),
//                    graphState: graph)
//                
//                // Calculate graph
//                graph.initializeGraphComputation()
//                
//                // Initialize preview layers
//                graph.updateOrderedPreviewLayers()
//            }
//        }
        
        
//        // MARK: important we don't initialize nodes until after media is estbalished
//        DispatchQueue.main.async { [weak self] in
//            if let graph = self {
//                dispatch(GraphInitialized(graph: graph,
//                                          data: data))
//            }
//        }
    }
    
    convenience init(from schema: GraphEntity,
                     saveLocation: [UUID],
                     encoder: (any DocumentEncodable)) async {
        guard let decodedFiles = await encoder.getDecodedFiles() else {
            fatalErrorIfDebug()
            self.init()
            return
        }
        
        self.init(from: schema,
                  saveLocation: saveLocation,
                  graphDecodedFiles: decodedFiles)
        
        await self.visibleNodesViewModel
            .updateNodeSchemaData(newNodes: schema.nodes,
                                  components: self.components,
                                  parentGraphPath: self.saveLocation)
    }
    
    func initializeDelegate(document: StitchDocumentViewModel,
                            documentEncoderDelegate: any DocumentEncodable) {
        self.documentDelegate = document
        self.documentEncoderDelegate = documentEncoderDelegate
        
        self.nodes.values.forEach { $0.initializeDelegate(graph: self,
                                                          document: document) }
        
        // Set up component graphs
        self.components.values.forEach {
            $0.initializeDelegate(parentGraph: self)
        }
        
        self.updateSidebarListStateAfterStateChange()
        
        // TODO: why is this necessary?
        _updateStateAfterListChange(
            updatedList: self.sidebarListState,
            expanded: self.getSidebarExpandedItems(),
            graphState: self)
        
        Task(priority: .high) {
            await MainActor.run { [weak self] in                
                // Calculate graph
                self?.initializeGraphComputation()
    
                // Initialize preview layers and topological data
                self?.updateGraphData()
            }
        }
        
        // Get media + encoded component files after view models are established
//        Task(priority: .high) { [weak self] in
//            await graph.documentEncoderDelegate?.graphInitialized()
//        }
    }
}

extension GraphState: GraphDelegate {
    var graphUI: GraphUIState {
        guard let graphUI = self.documentDelegate?.graphUI else {
            fatalErrorIfDebug()
            return GraphUIState(isPhoneDevice: false)
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
        self.graphUI.groupNodeFocused?.groupNodeId
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
    
    func undoDeletedMedia(mediaKey: MediaKey) async -> URLResult {
        await self.documentEncoderDelegate?.undoDeletedMedia(mediaKey: mediaKey) ?? .failure(.copyFileFailed)
    }
}

// extension StitchDocumentViewModel {
//     @MainActor convenience init(id: ProjectId,
//                                 projectName: String = STITCH_PROJECT_DEFAULT_NAME,
//                                 previewWindowSize: CGSize = PreviewWindowDevice.DEFAULT_PREVIEW_SIZE,
//                                 previewSizeDevice: PreviewWindowDevice = PreviewWindowDevice.DEFAULT_PREVIEW_OPTION,
//                                 previewWindowBackgroundColor: Color = DEFAULT_FLOATING_WINDOW_COLOR,
//                                 localPosition: CGPoint = .zero,
//                                 zoomData: CGFloat = 1,
//                                 nodes: [NodeEntity] = [],
//                                 orderedSidebarLayers: [SidebarLayerData] = [],
//                                 commentBoxes: [CommentBoxData] = .init(),
//                                 cameraSettings: CameraSettings = CameraSettings(),
//                                 store: StoreDelegate?) {
//         let document = StitchDocument(projectId: id,
//                                       name: projectName,
//                                       previewWindowSize: previewWindowSize,
//                                       previewSizeDevice: previewSizeDevice,
//                                       previewWindowBackgroundColor: previewWindowBackgroundColor,
//                                       localPosition: localPosition,
//                                       zoomData: zoomData,
//                                       nodes: nodes,
//                                       orderedSidebarLayers: orderedSidebarLayers,
//                                       commentBoxes: commentBoxes,
//                                       cameraSettings: cameraSettings)
//         self.init(from: document, store: store)
//     }
// }

// extension GraphState {
//     @MainActor convenience init(id: ProjectId,
//                                 projectName: String = STITCH_PROJECT_DEFAULT_NAME,
//                                 previewWindowSize: CGSize = PreviewWindowDevice.DEFAULT_PREVIEW_SIZE,
//                                 previewSizeDevice: PreviewWindowDevice = PreviewWindowDevice.DEFAULT_PREVIEW_OPTION,
//                                 previewWindowBackgroundColor: Color = DEFAULT_FLOATING_WINDOW_COLOR,
//                                 localPosition: CGPoint = .zero,
//                                 zoomData: CGFloat = 1,
//                                 nodes: [NodeEntity] = [],
//                                 orderedSidebarLayers: [SidebarLayerData] = [],
//                                 commentBoxes: [CommentBoxData] = .init(),
//                                 cameraSettings: CameraSettings = CameraSettings(),
//                                 store: StoreDelegate?) {
//         let document = StitchDocument(projectId: id,
//                                       name: projectName,
//                                       previewWindowSize: previewWindowSize,
//                                       previewSizeDevice: previewSizeDevice,
//                                       previewWindowBackgroundColor: previewWindowBackgroundColor,
//                                       localPosition: localPosition,
//                                       zoomData: zoomData,
//                                       nodes: nodes,
//                                       orderedSidebarLayers: orderedSidebarLayers,
//                                       commentBoxes: commentBoxes,
//                                       cameraSettings: cameraSettings)
//         self.init(from: document)
    // }
    
//    @MainActor
//    func update(from schema: StitchDocument) {
//        // Sync project attributes
//        self.id = schema.projectId
//        self.name = schema.name
//        self.orderedSidebarLayers = schema.orderedSidebarLayers
//        
//        
//    }

extension GraphState {
    @MainActor func createSchema() -> GraphEntity {
        assertInDebug(self.documentDelegate != nil)
        let documentDelegate = self.documentDelegate ?? .createEmpty()
        
        let nodes = self.visibleNodesViewModel.nodes.values
            .map { $0.createSchema() }
        let commentBoxes = self.commentBoxesDict.values.map { $0.createSchema() }
        
        let graph = GraphEntity(id: self.projectId,
                                name: documentDelegate.projectName,
                                nodes: nodes,
                                orderedSidebarLayers: self.orderedSidebarLayers,
                                commentBoxes: commentBoxes)
        return graph
    }
    
    @MainActor func update(from schema: GraphEntity) async {
        self.id = schema.id
        self.name = schema.name
        self.orderedSidebarLayers = schema.orderedSidebarLayers
        
        guard let decodedFiles = await self.documentEncoderDelegate?.getDecodedFiles() else {
            fatalErrorIfDebug()
            return
        }
        
        self.importedFilesDirectoryReceived(mediaFiles: decodedFiles.mediaFiles,
                                            components: decodedFiles.components)
        
//        if let documentViewModel = self.documentDelegate {
//            self.initializeDelegate(document: documentViewModel,
//                                    documentEncoderDelegate: documentViewModel.documentEncoder)
//        } else {
//            fatalErrorIfDebug()
//        }
        
        await self.visibleNodesViewModel.updateNodeSchemaData(newNodes: schema.nodes,
                                                              components: self.components,
                                                              parentGraphPath: self.saveLocation)
        
        if let document = self.documentDelegate,
           let documentEncoder = self.documentEncoderDelegate {
            self.initializeDelegate(document: document,
                                    documentEncoderDelegate: documentEncoder)
        }
        
        self.updateSidebarListStateAfterStateChange()
        
        // TODO: why is this necessary?
        _updateStateAfterListChange(
            updatedList: self.sidebarListState,
//            expanded: self.sidebarExpandedItems,
            expanded: self.getSidebarExpandedItems(),
            graphState: self)
        
        // Sync node view models + cached data
        self.updateGraphData()
        
        // No longer needed, since sidebar-expanded-items handled by node schema
//        self.sidebarExpandedItems = self.allGroupLayerNodes()
        self.calculateFullGraph()
        
        // TODO: comment boxes
    }
    
    @MainActor func onPrototypeRestart() {
        self.nodes.values.forEach { $0.onPrototypeRestart() }
        
        self.initializeGraphComputation()
    }
    
    var localPosition: CGPoint {
        self.documentDelegate?.localPosition ?? .init()
    }
    
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
    
    var llmRecording: LLMRecordingState {
        self.documentDelegate?.llmRecording ?? .init()
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
        self.visibleNodesViewModel.getVisibleNodes(at: self.graphUI.groupNodeFocused?.groupNodeId)
            .compactMap { node in
                guard node.kind == .patch(.wirelessBroadcaster) else {
                    return nil
                }
                
                return node
            }
    }
    
//    var allGraphs: [GraphState] {
//        [self] + self.components.values.flatMap {
//            $0.graph.allGraphs
//        }
//    }
    
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
        self.documentEncoderDelegate?.encodeProjectInBackground()
//        guard let documentViewModel = self.documentDelegate else {
//            fatalErrorIfDebug()
//            return
//        }
//        
//        documentViewModel.encodeProjectInBackground()
    }
    
//    @MainActor
//    func encodeProject(temporaryURL: DocumentsURL? = nil) {
//        self.documentEncoderDelegate?.encodeProject(temporaryURL: temporaryURL)
//        
////        guard let documentViewModel = self.documentDelegate else {
////            fatalErrorIfDebug()
////            return
////        }
////        
////        documentViewModel.encodeProject(temporaryURL: temporaryURL)
//    }
    
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
        case .component(let component):
            return [component.canvas]
        }
    }
    
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
    
    static func createEmpty() -> GraphState {
        .init()
    }
     
    convenience init() {
        self.init(from: .init(id: .init(),
                          name: STITCH_PROJECT_DEFAULT_NAME,
                          nodes: [],
                          orderedSidebarLayers: [],
                          commentBoxes: []),
              saveLocation: [],
              graphDecodedFiles: .init(mediaFiles: [],
                                       components: []))
    }
    
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

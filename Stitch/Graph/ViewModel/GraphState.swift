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
import SwiftUI
import Vision

// TODO: move
/// Tracks drafted and persisted versions of components, used to populate copies in graph.
final class StitchMasterComponent {
    let saveLocation: ComponentSaveLocation
    var publishedComponent: StitchComponent?
    var draftedComponent: StitchComponent
    
    // Encoded copy of drafted component
    let documentEncoder: ComponentEncoder
    
    weak var parentGraph: GraphState?
    
    @MainActor
    init(draftedComponent: StitchComponent,
         publishedComponent: StitchComponent? = nil,
         saveLocation: ComponentSaveLocation,
         parentGraph: GraphState?) {
        self.saveLocation = saveLocation
        self.draftedComponent = draftedComponent
        self.publishedComponent = publishedComponent
        self.documentEncoder = .init(component: draftedComponent,
                                     saveLocation: saveLocation)
        self.parentGraph = parentGraph
        
        self.documentEncoder.delegate = self
    }
}

extension StitchMasterComponent: SchemaObserverIdentifiable {
    func update(from schema: StitchComponent) {
        self.draftedComponent = schema
    }
    
    func createSchema() -> StitchComponent {
        self.draftedComponent
    }
    
    static func createObject(from entity: StitchComponent) -> Self {
        .init(draftedComponent: entity,
              saveLocation: .document,
              parentGraph: nil)
    }
    
    func onPrototypeRestart() { }
    
    func initializeDelegate(parentGraph: GraphState) {
        self.parentGraph = parentGraph
    }
}

typealias MasterComponentsDict = [UUID : StitchMasterComponent]

extension StitchMasterComponent: DocumentEncodableDelegate {
    var id: UUID {
        self.draftedComponent.id
    }
    
    func importedFilesDirectoryReceived(importedFilesDir: [URL],
                                        publishedComponents: [URL]) {
        guard let parentGraph = parentGraph else {
            fatalErrorIfDebug()
            return
        }
        
        // Find all graph states leveraging this component
        let componentGraphStates = parentGraph.nodes.values
            .compactMap { node -> GraphState? in
                guard let component = node.nodeType.componentNode,
                component.componentId == self.id else {
                    return nil
                }
                return component.graph
            }
        
        componentGraphStates.forEach { graphState in
            graphState.importedFilesDirectoryReceived(importedFilesDir: importedFilesDir,
                                                      publishedComponents: publishedComponents)
        }
        
        fatalError()
    }
}

extension GraphState {
    /// Recursively checks node component's `GraphState`'s until a match is found.
    func findComponentGraphState(_ id: ComponentGroupNodeId) -> GraphState? {
        for node in self.nodes.values {
            guard let nodeComponent = node.nodeType.componentNode else {
                continue
            }
            
            if node.id == id.nodeId {
                if nodeComponent.componentId == id.component {
                    return nodeComponent.graph
                } else {
                    return nil
                }
            }
            
            // Recursive check
            if let matchedGraph = nodeComponent.graph.findComponentGraphState(id) {
                return matchedGraph
            }
        }
        
        return nil
    }
}

@Observable
final class GraphState: Sendable {
    
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

    // Ordered list of layers in sidebar
    var orderedSidebarLayers: SidebarLayerList = []
    
    // Tracks all created and imported components
    var components: [UUID: StitchMasterComponent] = [:]

    // Maps a MediaKey to some URL
    var mediaLibrary: MediaLibrary = [:]

    // DEVICE MOTION
    var motionManagers = StitchMotionManagersDict()
    
    var networkRequestCompletedTimes = NetworkRequestLatestCompletedTimeDict()
    
    weak var documentDelegate: StitchDocumentViewModel?
    weak var documentEncoderDelegate: (any DocumentEncodable)?

    @MainActor init(from schema: GraphEntity) {
        self.id = schema.id
        self.name = schema.name
        self.commentBoxesDict.sync(from: schema.commentBoxes)
        self.components = schema.draftedComponents
            .reduce(into: [UUID: StitchMasterComponent]()) { result, componentEntity in
                let componentGraph = StitchMasterComponent(draftedComponent: componentEntity,
                                                           saveLocation: .document,
                                                           parentGraph: self)
                result.updateValue(componentGraph, forKey: componentEntity.graph.id)
            }
        
        self.visibleNodesViewModel.updateNodeSchemaData(newNodes: schema.nodes,
                                                        components: self.components)
        
//        // MARK: important we don't initialize nodes until after media is estbalished
//        DispatchQueue.main.async { [weak self] in
//            if let graph = self {
//                dispatch(GraphInitialized(graph: graph,
//                                          data: data))
//            }
//        }
    }
    
    @MainActor func initializeDelegate(document: StitchDocumentViewModel,
                                       documentEncoderDelegate: any DocumentEncodable) {
        self.documentDelegate = document
        self.documentEncoderDelegate = documentEncoderDelegate
        self.nodes.values.forEach { $0.initializeDelegate(graph: self) }
        
        // Set up component graphs
        self.components.values.forEach {
            $0.initializeDelegate(parentGraph: self)
        }
        
        // Get media + encoded component files after view models are established
        Task(priority: .high) { [weak self] in
            await self?.documentEncoderDelegate?.graphInitialized()
        }
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

        let draftedComponents = self.components.values
            .map { componentGraph in
                componentGraph.draftedComponent
        }
        
        let graph = GraphEntity(id: self.projectId,
                                name: documentDelegate.projectName,
                                nodes: nodes,
                                orderedSidebarLayers: self.orderedSidebarLayers,
                                commentBoxes: commentBoxes,
                                draftedComponents: draftedComponents)
        return graph
    }
    
    @MainActor func update(from schema: GraphEntity) {
        self.id = schema.id
        self.name = schema.name
        self.orderedSidebarLayers = schema.orderedSidebarLayers
        self.components.sync(with: schema.draftedComponents)
        
        if let documentViewModel = self.documentDelegate {
            self.initializeDelegate(document: documentViewModel,
                                    documentEncoderDelegate: documentViewModel.documentEncoder)
        } else {
            fatalErrorIfDebug()
        }
        
        self.visibleNodesViewModel.updateNodeSchemaData(newNodes: schema.nodes,
                                                        components: self.components)
        
        // TODO: comment boxes
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
        guard let documentViewModel = self.documentDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        documentViewModel.encodeProjectInBackground()
    }
    
    @MainActor
    func encodeProject(temporaryURL: DocumentsURL? = nil) {
        guard let documentViewModel = self.documentDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        documentViewModel.encodeProject(temporaryURL: temporaryURL)
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
    
    @MainActor static func createEmpty() -> GraphState {
        .init(from: .init(id: .init(),
                          name: STITCH_PROJECT_DEFAULT_NAME,
                          nodes: [],
                          orderedSidebarLayers: [],
                          commentBoxes: [],
                          draftedComponents: []))
    }
}

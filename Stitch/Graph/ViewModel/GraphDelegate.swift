//
//  GraphDelegate.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit
import StitchEngine

// Used only by GraphState
protocol GraphDelegate: AnyObject, Sendable, StitchDocumentIdentifiable {
    var documentDelegate: StitchDocumentViewModel? { get }
    
    var id: UUID { get }
    
    @MainActor var activeIndex: ActiveIndex { get }
    
    @MainActor var groupNodeFocused: NodeId? { get }
    
    @MainActor var mediaLibrary: MediaLibrary { get set }
    
    var motionManagers: StitchMotionManagersDict { get set }
    
    @MainActor var edgeDrawingObserver: EdgeDrawingObserver { get }
    
    @MainActor var safeAreaInsets: SafeAreaInsets { get }
    
    @MainActor var selectedEdges: Set<PortEdgeUI> { get }
    
    @MainActor var isFullScreenMode: Bool { get }
    
    @MainActor func getInputObserver(coordinate: NodeIOCoordinate) -> InputNodeRowObserver?
    
    // TODO: we can NEVER pass a keypath as part of retrieving an output
    @MainActor func getOutputObserver(coordinate: OutputPortViewData) -> OutputNodeRowObserver?
    
    @MainActor func getNodeViewModel(_ id: NodeId) -> NodeViewModel?
    
    @MainActor func getLayerInputOnGraph(_ id: LayerInputCoordinate) -> InputNodeRowViewModel?
    
    @MainActor func getLayerOutputOnGraph(_ id: LayerOutputCoordinate) -> OutputNodeRowViewModel?
    
    @MainActor func getMediaUrl(forKey: MediaKey) -> URL?
    
    func undoDeletedMedia(mediaKey: MediaKey) async -> URLResult

    @MainActor func getInputRowViewModel(for rowId: NodeRowViewModelId,
                                         nodeId: NodeId) -> InputNodeRowViewModel?
        
    @MainActor func getCanvasItem(_ id: CanvasItemId) -> CanvasItemViewModel?
    
    @MainActor var multiselectInputs: LayerInputTypeSet? { get }
    
    @MainActor
    var sidebarSelectionState: SidebarSelectionState { get set }
    
    @MainActor
    var orderedSidebarLayers: OrderedSidebarLayers { get }
}

extension GraphDelegate {
    var projectId: UUID { self.id }
    
    
    @MainActor var dragInteractionNodes: [LayerNodeId: NodeIdSet] {
        get {
            self.documentDelegate?.dragInteractionNodes ?? .init()
        }
        set(newValue) {
            self.documentDelegate?.dragInteractionNodes = newValue
        }
    }

    @MainActor var pressInteractionNodes: [LayerNodeId: NodeIdSet] {
        get {
            self.documentDelegate?.pressInteractionNodes ?? .init()
        }
        set(newValue) {
            self.documentDelegate?.pressInteractionNodes = newValue
        }
    }

    @MainActor var scrollInteractionNodes: [LayerNodeId: NodeIdSet] {
        get {
            self.documentDelegate?.scrollInteractionNodes ?? .init()
        }
        set(newValue) {
            self.documentDelegate?.scrollInteractionNodes = newValue
        }
    }
    
    @MainActor var graphStepState: GraphStepState {
        self.documentDelegate?.graphStepManager.graphStepState ??
            .init(estimatedFPS: .defaultAssumedFPS)
    }
    
    var cameraFeedManager: LoadingStatus<StitchSingletonMediaObject>? {
        self.documentDelegate?.cameraFeedManager
    }
    
    
    /// Invoked when nodes change on graph.
    @MainActor func updateGraphData(document: StitchDocument?) {
        self.documentDelegate?.updateGraphData(document: document)
    }
    
    var locationManager: LoadingStatus<StitchSingletonMediaObject>? {
        self.documentDelegate?.locationManager
    }
    
    // Calc
    @MainActor func calculateFullGraph() {
        self.documentDelegate?.calculateFullGraph()
    }
    
    @MainActor func calculate(_ id: NodeId) {
        self.documentDelegate?.calculate(id)
    }
    
    @MainActor func calculate(_ idSet: NodeIdSet) {
        self.documentDelegate?.calculate(idSet)
    }
      
    @MainActor func recalculateGraph(outputValues: AsyncMediaOutputs,
                                     nodeId: NodeId,
                                     loopIndex: Int) {
        self.documentDelegate?.recalculateGraph(outputValues: outputValues,
                                                nodeId: nodeId,
                                                loopIndex: loopIndex)
    }
    
    @MainActor func updateOutputs(at loopIndex: Int,
                                  node: NodeViewModel,
                                  portValues: PortValues) {
        self.documentDelegate?.updateOutputs(at: loopIndex,
                                             node: node,
                                             portValues: portValues)
    }
    
    @MainActor var shouldResortPreviewLayers: Bool {
        get {
            self.documentDelegate?.shouldResortPreviewLayers ?? false
        }
        set(newValue) {
            self.documentDelegate?.shouldResortPreviewLayers = newValue
        }
    }
    
    @MainActor var keypressState: KeyPressState {
        self.documentDelegate?.keypressState ?? .init()
    }
    
    @MainActor var previewWindowSize: CGSize {
        self.documentDelegate?.previewWindowSize ?? .init()
    }
    
    @MainActor var graphMovement: GraphMovementObserver {
        self.documentDelegate?.graphMovement ?? .init()
    }
    
    @MainActor var isGeneratingProjectThumbnail:  Bool {
        self.documentDelegate?.isGeneratingProjectThumbnail ?? false
    }
    
    @MainActor var connections: StitchDocumentViewModel.TopologicalData.Connections {
        self.documentDelegate?.connections ?? .init()
    }
    
    var cameraFeed: CameraFeedManager? {
        self.cameraFeedManager?.loadedInstance?.cameraFeedManager
    }
    
    @MainActor var cameraSettings: CameraSettings {
        self.documentDelegate?.cameraSettings ?? .init()
    }
}

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
    var projectId: UUID { get }
    
    @MainActor var isGeneratingProjectThumbnail:  Bool { get }
    
    @MainActor var shouldResortPreviewLayers: Bool { get set }
    
    @MainActor var activeIndex: ActiveIndex { get }
    
    @MainActor var groupNodeFocused: NodeId? { get }
    
    @MainActor var mediaLibrary: MediaLibrary { get set }
    
    var motionManagers: StitchMotionManagersDict { get set }
    
    @MainActor var nodesDict: NodesViewModelDict { get }
    
    @MainActor var connections: GraphState.TopologicalData.Connections { get }
    
    @MainActor var edgeDrawingObserver: EdgeDrawingObserver { get }
    
    @MainActor var dragInteractionNodes: [LayerNodeId: NodeIdSet] { get set }
    
    @MainActor var pressInteractionNodes: [LayerNodeId: NodeIdSet] { get set }
    
    @MainActor var scrollInteractionNodes: [LayerNodeId: NodeIdSet] { get set }
        
    @MainActor var cameraSettings: CameraSettings { get set }
    
    @MainActor var keypressState: KeyPressState { get }
    
    @MainActor var previewWindowSize: CGSize { get }
    
    @MainActor var graphMovement: GraphMovementObserver { get }
    
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
    
//    @MainActor func isConnectedToASelectedNode(at rowObserver: InputNodeRowObserver) -> Bool
//    
//    @MainActor func isConnectedToASelectedNode(at rowObserver: OutputNodeRowObserver) -> Bool
    
    @MainActor var graphStepState: GraphStepState { get }
    
    var cameraFeedManager: LoadingStatus<StitchSingletonMediaObject>? { get set }
    
    var locationManager: LoadingStatus<StitchSingletonMediaObject>? { get set }
    
    // Calc
    @MainActor func calculateFullGraph()
    
    @MainActor func calculate(_ id: NodeId)
      
    @MainActor func recalculateGraph(outputValues: AsyncMediaOutputs,
                                     nodeId: NodeId,
                                     loopIndex: Int)
    
    @MainActor func updateOutputs(at loopIndex: Int,
                                  node: NodeViewModel,
                                  portValues: PortValues)
    
    @MainActor
    var sidebarSelectionState: SidebarSelectionState { get }
    
    @MainActor
    var orderedSidebarLayers: OrderedSidebarLayers { get }
    
    /// Invoked when nodes change on graph.
    func updateGraphData(document: StitchDocument?)
}

extension GraphDelegate {
    var cameraFeed: CameraFeedManager? {
        self.cameraFeedManager?.loadedInstance?.cameraFeedManager
    }
}

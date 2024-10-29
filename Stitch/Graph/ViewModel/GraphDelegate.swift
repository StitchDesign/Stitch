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
protocol GraphDelegate: AnyObject, Sendable {
    var documentDelegate: StitchDocumentViewModel? { get }
    
    var id: UUID { get }
    
    var saveLocation: [UUID] { get }
    
    var activeIndex: ActiveIndex { get }
    
    var groupNodeFocused: NodeId? { get }
    
    var components: [UUID : StitchMasterComponent] { get }
    
    @MainActor var mediaLibrary: MediaLibrary { get set }
    
    var motionManagers: StitchMotionManagersDict { get set }
    
    var shouldResortPreviewLayers: Bool { get set }
    
    @MainActor var edgeDrawingObserver: EdgeDrawingObserver { get }
    
    @MainActor var safeAreaInsets: SafeAreaInsets { get }
    
    @MainActor var selectedEdges: Set<PortEdgeUI> { get }
    
    var isFullScreenMode: Bool { get }
    
    var dragInteractionNodes: [LayerNodeId: NodeIdSet] { get set }

    var pressInteractionNodes: [LayerNodeId: NodeIdSet] { get set }

    var scrollInteractionNodes: [LayerNodeId: NodeIdSet] { get set }
    
    var enabledCameraNodeIds: NodeIdSet { get set }

    var sidebarSelectionState: LayersSidebarViewModel.SidebarSelectionState { get }
    
    var isSidebarFocused: Bool { get set }
    
    @MainActor var connections: GraphState.TopologicalData.Connections { get }
    
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
    
    var layersSidebarViewModel: LayersSidebarViewModel { get }
    
    var orderedSidebarLayers: OrderedSidebarLayers { get }

    @MainActor func updateGraphData()
    
    // Calc
    @MainActor func calculateFullGraph()
    
    @MainActor func calculate(_ id: NodeId)
    
    @MainActor func calculate(_ idSet: NodeIdSet)
      
    @MainActor func recalculateGraph(outputValues: AsyncMediaOutputs,
                                     nodeId: NodeId,
                                     loopIndex: Int)
    
    @MainActor
    func updateOutputs(at loopIndex: Int,
                       node: NodeViewModel,
                       portValues: PortValues)
    
    @MainActor
    func children(of parent: NodeId) -> NodeViewModels
}

extension GraphState {
    @MainActor
    func children(of parent: NodeId) -> NodeViewModels {
        self.layerNodes.values.filter { layerNode in
            layerNode.layerNode?.layerGroupId == parent
        }
    }
}

extension GraphDelegate {
    var projectId: UUID { self.id }
    
    @MainActor var graphStepState: GraphStepState {
        self.documentDelegate?.graphStepManager.graphStepState ??
            .init(estimatedFPS: .defaultAssumedFPS)
    }
    
    var cameraFeedManager: LoadingStatus<StitchSingletonMediaObject>? {
        self.documentDelegate?.cameraFeedManager
    }
    
    var locationManager: LoadingStatus<StitchSingletonMediaObject>? {
        self.documentDelegate?.locationManager
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
    
    var cameraFeed: CameraFeedManager? {
        self.cameraFeedManager?.loadedInstance?.cameraFeedManager
    }
    
    @MainActor var cameraSettings: CameraSettings {
        self.documentDelegate?.cameraSettings ?? .init()
    }
}

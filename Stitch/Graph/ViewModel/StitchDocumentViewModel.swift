//
//  StitchDocumentViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 9/16/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import StitchEngine

let STITCH_PROJECT_DEFAULT_NAME = StitchDocument.defaultName

extension StitchDocumentViewModel: Hashable {
    static func == (lhs: StitchDocumentViewModel, rhs: StitchDocumentViewModel) -> Bool {
        lhs.graph.id == rhs.graph.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.graph.id)
    }
}

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
        self.graph.id = schema.projectId
        self.graph.name = schema.name
        self.graph.orderedSidebarLayers = schema.orderedSidebarLayers
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

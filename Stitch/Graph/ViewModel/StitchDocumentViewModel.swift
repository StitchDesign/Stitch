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
        lhs.rootId == rhs.rootId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.rootId)
    }
}

@Observable
final class StitchDocumentViewModel: Sendable {
    let rootId: UUID
    let graph: GraphState
    let graphUI: GraphUIState
    let graphStepManager = GraphStepManager()
    let graphMovement = GraphMovementObserver()
    
    let previewWindowSizingObserver = PreviewWindowSizing()
    
    @MainActor var isGeneratingProjectThumbnail = false
    
    // The raw size we pass to GeneratePreview
    @MainActor var previewWindowSize: CGSize = PreviewWindowDevice.DEFAULT_PREVIEW_SIZE
    
    // Changed by e.g. project-settings modal, e.g. UpdatePreviewCanvasDevice;
    // Not changed by user's manual drag on the preview window handle.
    @MainActor var previewSizeDevice: PreviewWindowDevice = PreviewWindowDevice.DEFAULT_PREVIEW_OPTION
    
    @MainActor var previewWindowBackgroundColor: Color = DEFAULT_FLOATING_WINDOW_COLOR
    
    @MainActor var cameraSettings = CameraSettings()
    
    @MainActor var keypressState = KeyPressState()
    @MainActor var llmRecording = LLMRecordingState()
    @MainActor var stitchAI = StitchAIState()

    // Remains false if an encoding action never happened (used for thumbnail creation)
    @MainActor var didDocumentChange: Bool = false
    
    // Singleton instances
    @MainActor var locationManager: LoadingStatus<StitchSingletonMediaObject>?
    @MainActor var cameraFeedManager: LoadingStatus<StitchSingletonMediaObject>?
    
    @MainActor var lastEncodedDocument: StitchDocument
    
    @MainActor weak var storeDelegate: StoreDelegate?
    @MainActor weak var projectLoader: ProjectLoader?
    @MainActor weak var documentEncoder: DocumentEncoder?
    
    @MainActor
    init(from schema: StitchDocument,
         graph: GraphState,
         isPhoneDevice: Bool,
         projectLoader: ProjectLoader,
         store: StoreDelegate?) {
        self.rootId = schema.id
        self.documentEncoder = projectLoader.encoder
        self.previewWindowSize = schema.previewWindowSize
        self.previewSizeDevice = schema.previewSizeDevice
        self.previewWindowBackgroundColor = schema.previewWindowBackgroundColor
        self.cameraSettings = schema.cameraSettings
        self.graphMovement.localPosition = schema.localPosition
        self.graphUI = GraphUIState(isPhoneDevice: isPhoneDevice)
        self.graph = graph
        self.projectLoader = projectLoader
        self.lastEncodedDocument = schema
        
        if let store = store {
            self.initializeDelegate(store: store,
                                    isInitialization: true)
        }
    }
    
    @MainActor
    func initializeDelegate(store: StoreDelegate,
                            isInitialization: Bool = false) {
        self.documentEncoder?.delegate = self
        self.graphStepManager.delegate = self
        self.storeDelegate = store
        
        guard let documentEncoder = self.documentEncoder else {
//            fatalErrorIfDebug()
            return
        }
        
        self.graph.initializeDelegate(document: self,
                                      documentEncoderDelegate: documentEncoder)
        
        // Start graph
        self.graphStepManager.start()
        
        // Updates node location data for perf + edge UI
        // MARK: currently testing perf without visibility check
        if isInitialization {
            // Need all nodes to render initially
            let visibleGraph = self.visibleGraph
            visibleGraph.visibleNodesViewModel.setAllNodesVisible()
        } else {
//            self.refreshVisibleNodes()
        }
    }
    
    @MainActor
    convenience init?(from schema: StitchDocument,
                      isPhoneDevice: Bool,
                      projectLoader: ProjectLoader,
                      store: StoreDelegate?) async {
        let documentEncoder = DocumentEncoder(document: schema)

        let graph = await GraphState(from: schema.graph,
                                     saveLocation: [],
                                     encoder: documentEncoder)
        self.init(from: schema,
                  graph: graph,
                  isPhoneDevice: isPhoneDevice,
                  projectLoader: projectLoader,
                  store: store)
    }
}

extension StitchDocumentViewModel: DocumentEncodableDelegate {    
    func willEncodeProject(schema: StitchDocument) {
        // Signals to project thumbnail logic to create a new one when project closes
        self.didDocumentChange = true
    }
}

extension StitchDocumentViewModel {
    @MainActor
    var id: UUID {
        self.graph.id
    }
    
    @MainActor
    var projectId: UUID {
        self.id
    }
    
    @MainActor
    var projectName: String {
        self.graph.name
    }

    /// Returns `GraphState` instance based on visited groups and components
    @MainActor var visibleGraph: GraphState {
        // Traverse in reverse order of view stack
        for groupType in self.graphUI.groupNodeBreadcrumbs.reversed() {
            switch groupType {
            case .groupNode:
                continue
            case .component:
                // TODO: bug with accessing ID
                guard let nodeId = groupType.component else {
                    fatalError()
                }
                
                guard let componentGraph = self.graph.findComponentGraphState(nodeId) else {
                    fatalErrorIfDebug()
                    return self.graph
                }
                
                return componentGraph
            }
        }
        
        // No visited component
        return self.graph
    }
    
    @MainActor var activeIndex: ActiveIndex {
        self.graphUI.activeIndex
    }
    
    @MainActor var graphStepState: GraphStepState {
        self.graphStepManager.graphStepState
    }
    
    @MainActor
    var cameraFeed: CameraFeedManager? {
        self.cameraFeedManager?.loadedInstance?.cameraFeedManager
    }

    @MainActor
    func encodeProjectInBackground(temporaryURL: URL? = nil,
                                   willUpdateUndoHistory: Bool = true) {
        self.documentEncoder?.encodeProjectInBackground(from: self.graph,
                                                        temporaryUrl: temporaryURL,
                                                        willUpdateUndoHistory: willUpdateUndoHistory)
    }
    
    /// Determines if camera is in use by looking at main graph + all component graphs to determine if any camera
    /// node is enabled. Complexity handled here as there can only be one running camera session.
    @MainActor
    var isCameraEnabled: Bool {
        self.allGraphs.contains {
            !$0.enabledCameraNodeIds.isEmpty
        }
    }
    
    /// Returns self and all graphs inside component instances.
    @MainActor
    var allGraphs: [GraphState] {
        [self.graph] + self.graph.allComponentGraphs
    }
    
    /// Returns all components inside graph instances.
    @MainActor
    var allComponents: [StitchComponentViewModel] {
        self.graph.allComponents
    }
    
    @MainActor func calculateAllKeyboardNodes() {
        self.allGraphs.forEach { graph in
            let keyboardNodes = graph.keyboardNodes
            graph.calculate(keyboardNodes)
        }
    }
}

extension GraphState: GraphCalculatable {
    
    @MainActor
    func updateOrderedPreviewLayers() {
        // Cannot use Equality check here since LayerData does not conform to Equatable;
        // so instead we should be smart about only calling this when layer nodes actually change.
        
        let flattenedPinMap = self.getFlattenedPinMap()
        let rootPinMap = self.getRootPinMap(pinMap: flattenedPinMap)
        
        let previewLayers: LayerDataList = self.recursivePreviewLayers(
            sidebarLayersGlobal: self.layersSidebarViewModel.createdOrderedEncodedData(),
            pinMap: rootPinMap)
        
        self.cachedOrderedPreviewLayers = previewLayers
        self.flattenedPinMap = flattenedPinMap
        self.pinMap = rootPinMap
    }
    
    @MainActor
    func getNodesToAlwaysRun() -> Set<UUID> {
        Array(self.nodes
                .values
                .filter { $0.patch?.willAlwaysRunEval ?? false }
                .map(\.id))
            .toSet
    }
    
    @MainActor
    func getAnimationNodes() -> Set<UUID> {
        Array(self.nodes
                .values
                .filter { $0.patch?.isAnimationNode ?? false }
                .map(\.id))
            .toSet
    }
    
    @MainActor
    func getNodeViewModel(id: UUID) -> NodeViewModel? {
        self.getNodeViewModel(id)
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func updateAsync(from schema: StitchDocument) async {
        // Sync preview window attributes
        self.previewWindowSize = schema.previewWindowSize
        self.previewSizeDevice = schema.previewSizeDevice
        self.previewWindowBackgroundColor = schema.previewWindowBackgroundColor

        await self.graph.updateAsync(from: schema.graph)
    }
    
    @MainActor func createSchema() -> StitchDocument {
        StitchDocument(graph: self.graph.createSchema(),
                       previewWindowSize: self.previewWindowSize,
                       previewSizeDevice: self.previewSizeDevice,
                       previewWindowBackgroundColor: self.previewWindowBackgroundColor,
                       // Important: `StitchDocument.localPosition` currently represents only the root level's graph-offset
                       localPosition: self.localPositionToPersist,
                       zoomData: self.graphMovement.zoomData.zoom,
                       cameraSettings: self.cameraSettings)
    }
    
    @MainActor func createSchema(from graph: GraphState?) -> StitchDocument {
        self.createSchema()
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
    }
    
    @MainActor static func createEmpty() -> StitchDocumentViewModel {
        .init(from: .init(),
              graph: .init(),
              isPhoneDevice: false,
              projectLoader: .init(url: URL(fileURLWithPath: "")),
              store: nil)
    }
}

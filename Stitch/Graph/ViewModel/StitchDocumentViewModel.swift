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

@Observable
final class StitchDocumentViewModel: Sendable {
    let rootId: UUID
    let isDebugMode: Bool
    let graph: GraphState
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
        
    let aiManager: StitchAIManager?
    
    // Remains false if an encoding action never happened (used for thumbnail creation)
    @MainActor var didDocumentChange: Bool = false
    
    // Singleton instances
    @MainActor var locationManager: LoadingStatus<StitchSingletonMediaObject>?
    @MainActor var cameraFeedManager: LoadingStatus<StitchSingletonMediaObject>?
        
    @MainActor var sidebarWidth: CGFloat = .zero // i.e. origin of graph from .global frame

    @MainActor var showCatalystProjectTitleModal: Bool = false
    
    @MainActor var restartPrototypeWindowIconRotationZ: CGFloat = .zero

    // nil = no field focused
    @MainActor var reduxFocusedField: FocusedUserEditField?
    
    // set non-nil by up- and down-arrow key presses while an input's fields are focused
    // set nil after key press has been handled by `StitchTextEditingBindingField`
    @MainActor var reduxFocusedFieldChangedByArrowKey: FocusedFieldChangedByArrowKey?

    // Hack: to differentiate state updates that came from undo/redo (and which close the adjustment bar popover),
    // vs those that came from user manipulation of adjustment bar (which do not close the adjustment bar popover).
    @MainActor var adjustmentBarSessionId: UUID = .init()
    
    @MainActor
    static let isPhoneDevice = Stitch.isPhoneDevice
    
    @MainActor var activeSpacebarClickDrag = false

    @MainActor var safeAreaInsets = SafeAreaInsetsEnvironmentKey.defaultValue
    @MainActor var colorScheme: ColorScheme = defaultColorScheme
    
    // which loop index to show
    @MainActor var activeIndex: ActiveIndex = ActiveIndex(0)
    
    // Starts out as default value, but on first render of GraphView
    // we get the exact device screen size via GeometryReader.
    @MainActor var frame = DEFAULT_LANDSCAPE_GRAPH_FRAME
    
    // Control animation direction when group nodes are traversed
    @MainActor var groupTraversedToChild = false

    // Only applies to non-iPhones so that exiting full-screen mode goes
    // back to graph instead of projects list
    @MainActor var isFullScreenMode: Bool = false
    
    @MainActor var showsLayerInspector = false
    
    @MainActor var leftSidebarOpen = false
    
    // Tracks group breadcrumbs when group nodes are visited
    @MainActor var groupNodeBreadcrumbs: [GroupNodeType] = [] {
        didSet {
            if let nodePageData = self.graph.visibleNodesViewModel.nodePageDataAtCurrentTraversalLevel(self.groupNodeFocused?.groupNodeId) {

                self.graph.canvasPageOffsetChanged = nodePageData.localPosition
                self.graph.canvasPageZoomScaleChanged = nodePageData.zoomData
                
                // Set all nodes visible so that input/output fields' UI update when we enter a new traversal level
                self.graph.visibleNodesViewModel.setAllNodesVisible()
                
                // Note: refreshing graph-updater-id here in `didSet` seems preferable to `myView.onChange(groupNodeId)`;
                // seems to remove race condition where groupNodeId change would not trigger the proper re-render.
                self.graph.refreshGraphUpdaterId()
                
                // User will probably have moved the graph or done something else to trigger an `updateVisibleNodes` call; but we put this here just in case they don't.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    log("calling updateVisibleNodes after 1 second")
                    self?.graph.updateVisibleNodes()
                }
            }
        }
    }

    @MainActor var showPreviewWindow = PREVIEW_SHOWN_DEFAULT_STATE
    
    @MainActor var insertNodeMenuState = InsertNodeMenuState()
    @MainActor var nodeMenuHeight: CGFloat = INSERT_NODE_MENU_MAX_HEIGHT

    /*
     Similar to `activeDragInteraction`, but just for mouse nodes.
     - nil when LayerHoverEnded or LayerDragEnded
     - non-nil when LayerHovered or LayerDragged
     - when non-nil and it’s been more than `DRAG_NODE_VELOCITY_RESET_STEP` since last movement, reset velocity to `.zero`
     */
    @MainActor var lastMouseNodeMovement: TimeInterval?
    
    @MainActor var openPortPreview: OpenedPortPreview?
    
    @MainActor weak var storeDelegate: StitchStore?
    @MainActor weak var projectLoader: ProjectLoader?
    @MainActor weak var documentEncoder: DocumentEncoder?
    
    @MainActor
    init(from schema: StitchDocument,
         graph: GraphState,
         isPhoneDevice: Bool,
         projectLoader: ProjectLoader,
         store: StoreDelegate?,
         isDebugMode: Bool) {
        self.rootId = schema.id
        self.documentEncoder = projectLoader.encoder
        self.previewWindowSize = schema.previewWindowSize
        self.previewSizeDevice = schema.previewSizeDevice
        self.previewWindowBackgroundColor = schema.previewWindowBackgroundColor
        self.cameraSettings = schema.cameraSettings
        self.graphMovement.localPosition = schema.localPosition
        self.graph = graph
        self.projectLoader = projectLoader
        self.isDebugMode = isDebugMode
        
        // Handles Stitch AI if enabled
//#if STITCH_AI
        do {
            self.aiManager = try StitchAIManager()
        } catch {
            self.aiManager = nil
            log("StitchStore error: could not init secrets file with error: \(error)")
        }
//#else
//        self.aiManager = nil
//#endif

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
        self.aiManager?.documentDelegate = self
        self.storeDelegate = store
        
        guard let documentEncoder = self.documentEncoder else {
//            fatalErrorIfDebug()
            return
        }
        
        self.graph.initializeDelegate(document: self,
                                      documentEncoderDelegate: documentEncoder)
        
        // Start graph if not in debug mode
        if !self.isDebugMode {
            self.graphStepManager.start()            
        }
        
        // Updates node location data for perf + edge UI
        // MARK: currently testing perf without visibility check
        if isInitialization {
            // Need all nodes to render initially
            let visibleGraph = self.visibleGraph
            visibleGraph.visibleNodesViewModel.setAllNodesVisible()
        }
    }
    
    @MainActor
    convenience init?(from schema: StitchDocument,
                      isPhoneDevice: Bool,
                      projectLoader: ProjectLoader,
                      store: StoreDelegate?,
                      isDebugMode: Bool) async {
        let documentEncoder = DocumentEncoder(document: schema)

        let graph = await GraphState(from: schema.graph,
                                     localPosition: ABSOLUTE_GRAPH_CENTER, // schema.localPosition,
                                     saveLocation: [],
                                     encoder: documentEncoder)
                
        self.init(from: schema,
                  graph: graph,
                  isPhoneDevice: isPhoneDevice,
                  projectLoader: projectLoader,
                  store: store,
                  isDebugMode: isDebugMode)
    }
}

extension StitchDocumentViewModel: DocumentEncodableDelegate {
    @MainActor var lastEncodedDocument: StitchDocument {
        get {
            guard let document = self.projectLoader?.lastEncodedDocument else {
//                fatalErrorIfDebug()
                return StitchDocument()
            }
            
            return document
        }
        set(newValue) {
            guard let projectLoader = self.projectLoader else {
                fatalErrorIfDebug()
                return
            }
            
            projectLoader.lastEncodedDocument = newValue
            projectLoader.loadingDocument = .loaded(newValue,
                                                    self.projectLoader?.thumbnail)
        }
    }
    
    func willEncodeProject(schema: StitchDocument) {
        // Signals to project thumbnail logic to create a new one when project closes
        self.didDocumentChange = true
        
        // Blocks thumbnail from being selected until encoding completes
        self.projectLoader?.loadingDocument = .loading
        
        // Checks if AI edit mode is enabled and if actions should be updated
        if self.llmRecording.isRecording || self.llmRecording.mode == .augmentation {
            let oldActions = self.llmRecording.actions
            let newActions = self.deriveNewAIActions()
            
            if oldActions != newActions {
                self.llmRecording.actions = newActions
                
                if self.llmRecording.willAutoValidate {
                    do {
                        try self.reapplyActions()
                    } catch let error as StitchAIManagerError {
                        self.llmRecording.actionsError = error.description
                    } catch {
                        self.llmRecording.actionsError = error.localizedDescription
                    }
                }
            }
        }
        
        // Updates graph data when changed
        self.visibleGraph.refreshGraphUpdaterId()
    }
    
    func didEncodeProject(schema: StitchDocument) {
        self.projectLoader?.loadingDocument = .loaded(schema,
                                                      self.projectLoader?.thumbnail)
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
            graph.scheduleForNextGraphStep(keyboardNodes)
        }
    }
}

extension GraphState: GraphCalculatable {
    @MainActor
    func didPortsUpdate(ports: Set<StitchEngine.NodePortType<NodeViewModel>>) {
        // Update multi-selected layers in sidebar with possible heterogenous values
        if let currentMultiselectionMap = self.propertySidebar.heterogenousFieldsMap {
            let newMultiselectionMap = Set(currentMultiselectionMap.keys)
                .getHeterogenousFieldsMap(graph: self)
            
            if currentMultiselectionMap != newMultiselectionMap {
                self.propertySidebar.heterogenousFieldsMap = newMultiselectionMap
            }
        }
    }
    
    
    @MainActor
    func updateOrderedPreviewLayers() {
        let flattenedPinMap = self.getFlattenedPinMap()
        let rootPinMap = self.getRootPinMap(pinMap: flattenedPinMap)
        
        let previewLayers: LayerDataList = self.recursivePreviewLayers(
            sidebarLayersGlobal: self.layersSidebarViewModel.createdOrderedEncodedData(),
            pinMap: rootPinMap,
            activeIndex: self.documentDelegate?.activeIndex ?? .init(.zero))
        
        if !LayerDataList.equals(self.cachedOrderedPreviewLayers, previewLayers) {
            self.cachedOrderedPreviewLayers = previewLayers
        }
        if self.flattenedPinMap != flattenedPinMap {
            self.flattenedPinMap = flattenedPinMap
        }
        if self.pinMap != rootPinMap {
            self.pinMap = rootPinMap
        }
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
                       // TODO: we currently are not actually using persisted graph-offset; we always open graph afresh to the absolute-center
                       localPosition: ABSOLUTE_GRAPH_CENTER, // self.localPositionToPersist,
                       zoomData: self.graphMovement.zoomData,
                       cameraSettings: self.cameraSettings)
    }
    
    @MainActor func createSchema(from graph: GraphState?) -> StitchDocument {
        self.createSchema()
    }
    
    @MainActor func onPrototypeRestart() {
        self.graphStepManager.resetGraphStepState()
        
        self.graph.onPrototypeRestart()
        
        // Defocus the preview window's TextField layer
        if self.reduxFocusedField?.getTextFieldLayerInputEdit.isDefined ?? false {
            self.reduxFocusedField = nil
        }
        
        // Update animation value for restart-prototype icon;
        self.restartPrototypeWindowIconRotationZ += 360
    }
    
    @MainActor static func createEmpty() -> StitchDocumentViewModel {
        .init(from: .init(),
              graph: .init(),
              isPhoneDevice: false,
              projectLoader: .init(url: URL(fileURLWithPath: "")),
              store: nil,
              isDebugMode: false)
    }
}

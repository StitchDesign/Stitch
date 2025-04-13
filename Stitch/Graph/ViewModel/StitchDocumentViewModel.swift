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
import OrderedCollections

let STITCH_PROJECT_DEFAULT_NAME = StitchDocument.defaultName

// Use a type-wrapper so we avoid mistakes where we think `.init()` creates a random id like a regular UUID
// see https://github.com/StitchDesign/Stitch--Old/issues/7090
struct GraphUpdaterId: Equatable, Hashable, Sendable, Codable {
    let value: Int
        
    static func randomId() -> Self {
        .init(value: .random(in: -999...999))
    }
}

@Observable
final class StitchDocumentViewModel: Sendable {
    // TODO: what kind of id is this? Per data flow, it's from StitchDocumentViewModel.id which is from document.graphId i.e. it's the id for the document's root
    let rootId: UUID // Previously was just `UUID`, taken from StitchDocument.id which was from
    
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
    
    @MainActor var leftSidebarOpen = false

    // Note: important to use `OrderedSet` rather than just list, so that we never have duplicate traversal-levels, see: https://github.com/StitchDesign/Stitch--Old/issues/7038
    // Tracks group breadcrumbs when group nodes are visited
    @MainActor var groupNodeBreadcrumbs: OrderedSet<GroupNodeType> = .init()

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
    
    /// Subscribed by view to trigger graph view update based on data changes.
    @MainActor var graphUpdaterId: GraphUpdaterId = .init(value: .zero)
    
    @MainActor weak var storeDelegate: StitchStore?
    @MainActor weak var projectLoader: ProjectLoader?
    @MainActor weak var documentEncoder: DocumentEncoder?
    
    @MainActor
    init(from schema: StitchDocument,
         graph: GraphState,
         projectLoader: ProjectLoader,
         store: StitchStore,
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
        
        self.initializeDelegate(store: store,
                                isInitialization: true)
    }
    
    @MainActor
    func initializeDelegate(store: StitchStore,
                            isInitialization: Bool = false) {
        self.documentEncoder?.delegate = self
        self.graphStepManager.delegate = self
        self.aiManager?.documentDelegate = self
        self.storeDelegate = store
        
        guard let documentEncoder = self.documentEncoder else {
            // fatalErrorIfDebug()
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
            visibleGraph.visibleNodesViewModel.setAllCanvasItemsVisible()
        }
    }
    
    @MainActor
    convenience init?(from schema: StitchDocument,
                      projectLoader: ProjectLoader,
                      store: StitchStore,
                      isDebugMode: Bool) async {
        let documentEncoder = DocumentEncoder(document: schema)

        let graph = await GraphState(from: schema.graph,
                                     localPosition: ABSOLUTE_GRAPH_CENTER, // schema.localPosition,
                                     saveLocation: [],
                                     encoder: documentEncoder)
                
        self.init(from: schema,
                  graph: graph,
                  projectLoader: projectLoader,
                  store: store,
                  isDebugMode: isDebugMode)
    }
}

extension StitchDocumentViewModel: DocumentEncodableDelegate {
    @MainActor
    func update(from schema: StitchDocument, rootUrl: URL?) {
        // Sync preview window attributes
        self.previewWindowSize = schema.previewWindowSize
        self.previewSizeDevice = schema.previewSizeDevice
        self.previewWindowBackgroundColor = schema.previewWindowBackgroundColor

        self.graph.update(from: schema.graph, rootUrl: rootUrl)
    }
    
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
    
   @MainActor
   func refreshGraphUpdaterId() {
       // log("refreshGraphUpdaterId called")
       let newId = self.calculateGraphUpdaterId()
       
       if self.graphUpdaterId != newId {
           // log("refreshGraphUpdaterId: newId: \(newId)")
           self.graphUpdaterId = newId
       }
   }
    
    /// Creases a unique hash based on view data which if changes, requires graph data update.
    @MainActor
    func calculateGraphUpdaterId() -> GraphUpdaterId {
        var hasher = Hasher()
        
        let graph = self.visibleGraph
        
        let nodes = graph.nodes
        
        let allInputsObservers = nodes.values
            .flatMap { $0.getAllInputsObservers() }
        
        // Track overall node count
        let nodeCount = nodes.keys.count
        
        // Track graph canvas items count
        let canvasItems = graph.getCanvasItemsAtTraversalLevel(groupNodeFocused: self.groupNodeFocused?.groupNodeId).count

        // Tracks edge changes to reset cached data
        let upstreamConnections = allInputsObservers
        // Important: use compactMap, otherwise `nil` (i.e. non-existence connections) will be counted as a valid connection
            .compactMap { $0.upstreamOutputCoordinate }
        
        // Tracks manual edits
        let manualEdits: [PortValue] = allInputsObservers
            .compactMap {
                guard $0.upstreamOutputCoordinate == nil else {
                    return nil
                }
                
                return $0.getActiveValue(activeIndex: self.activeIndex)
            }
        
        // Track group node ID, which fixes edges when traversing
        let groupNodeIdFocused = self.groupNodeFocused
        
        // Stitch AI changes in case order changes
        let aiActions = self.llmRecording.actions
        
        // Labels for splitter nodes
        let splitterLabels = graph.getGroupPortLabels()
        
        hasher.combine(nodeCount)
        hasher.combine(canvasItems)
        hasher.combine(upstreamConnections)
        hasher.combine(manualEdits)
        hasher.combine(groupNodeIdFocused)
        hasher.combine(aiActions)
        hasher.combine(splitterLabels)
        
        let newGraphUpdaterId = hasher.finalize()
        // log("calculateGraphUpdaterId: newGraphUpdaterId: \(newGraphUpdaterId)")
        return .init(value: newGraphUpdaterId)
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
        self.refreshGraphUpdaterId()
    }
    
    func didEncodeProject(schema: StitchDocument) {
        self.projectLoader?.loadingDocument = .loaded(schema,
                                                      self.projectLoader?.thumbnail)
    }
}

extension StitchDocumentViewModel {
    @MainActor
    var id: GraphId {
        self.graph.id
    }
        
    @MainActor
    var projectName: String {
        self.graph.name
    }

    /// Returns `GraphState` instance based on visited groups and components
    @MainActor var visibleGraph: GraphState {
        // Traverse in reverse order of view stack
        for groupType in self.groupNodeBreadcrumbs.reversed() {
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
        guard let store = self.storeDelegate,
              let documentEncoder = self.documentEncoder else {
            log("encodeProjectInBackground: missing store and/or decoder delegates")
            // fatalErrorIfDebug()
            return
        }
        
        documentEncoder.encodeProjectInBackground(from: self.graph,
                                                  temporaryUrl: temporaryURL,
                                                  willUpdateUndoHistory: willUpdateUndoHistory,
                                                  store: store)
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
    var currentGraphTime: TimeInterval {
        self.graphStepManager.graphTime
    }
    
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
        guard let activeIndex = self.documentDelegate?.activeIndex else {
            fatalErrorIfDebug()
            return
        }
        
        let flattenedPinMap = self.getFlattenedPinMap()
        let rootPinMap = self.getRootPinMap(pinMap: flattenedPinMap)
        
        let previewLayers: LayerDataList = self.recursivePreviewLayers(
            sidebarLayersGlobal: self.layersSidebarViewModel.createdOrderedEncodedData(),
            pinMap: rootPinMap,
            activeIndex: activeIndex)
        
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
    
    @MainActor func createSchema(from graph: GraphState) -> StitchDocument {
        self.createSchema()
    }
    
    @MainActor func onPrototypeRestart(document: StitchDocumentViewModel) {
        self.graphStepManager.resetGraphStepState()
        
        self.graph.onPrototypeRestart(document: document)
        
        // Defocus the preview window's TextField layer
        if self.reduxFocusedField?.getTextFieldLayerInputEdit.isDefined ?? false {
            self.reduxFocusedField = nil
        }
        
        // Update animation value for restart-prototype icon;
        self.restartPrototypeWindowIconRotationZ += 360
    }
    
    // TODO: this still doesn't quite have the correct projectLoader/encoderDelegate needed for all uses in the app
    @MainActor
    static func createTestFriendlyDocument(_ store: StitchStore) -> StitchDocumentViewModel {
//        let store = StitchStore()
        let (projectLoader, documentViewModel) = try! createNewEmptyProject(store: store)
        store.navPath = [projectLoader]
                
        assert(documentViewModel.documentEncoder.isDefined)
        assert(documentViewModel.graph.documentEncoderDelegate.isDefined)
        
        return documentViewModel
    }
    
    @MainActor static func createEmpty() -> StitchDocumentViewModel {
        let store = StitchStore()
        let doc = StitchDocument()
        let loader = ProjectLoader(url: URL(fileURLWithPath: ""))
        
        return .init(from: doc,
                     graph: .init(),
                     projectLoader: loader,
                     store: store,
                     isDebugMode: false)
    }
}

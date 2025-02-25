//
//  GraphUI.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/10/21.
//

import SwiftUI
import StitchSchemaKit

let DEFAULT_LANDSCAPE_ORIGIN = CGPoint(x: 0.0, y: 24.0)

// 12.9-inch 5th generation iPad
let DEFAULT_LANDSCAPE_SIZE = CGSize(width: 1366.0, height: 980.0)

// 11-inch 3rd generation iPad
// let DEFAULT_LANDSCAPE_SIZE = CGSize(width: 1194.0, height: 790.0)

let DEFAULT_LANDSCAPE_GRAPH_FRAME = CGRect(
    origin: DEFAULT_LANDSCAPE_ORIGIN,
    size: DEFAULT_LANDSCAPE_SIZE)

// We must reset a drag interaction node's velocity output when "user has finger in resting position but not yet lifted up",
// i.e. when LayerDragged is not firing and LayerDragEnded has not fired yet either.
struct ActiveDragInteractionNodeVelocityData: Equatable, Hashable {

    // Added to in LayerDragged; removed from in LayerDragEnded; wiped in GraphStepIncremented
    var activeDragInteractionNodes = NodeIdSet()
}

enum FocusedFieldChangedByArrowKey: Equatable, Hashable {
    case upArrow, // increment
         downArrow // decrement
}

@Observable
final class GraphUIState: Sendable {
        
    // Set true / non-nil in redux-actions
    // Set false in StitchUIScrollView
    // TODO: combine canvasZoomedIn and canvasZoomedOut? can never have both at same time? or we can, and they cancel each other?
    @MainActor var canvasZoomedIn: GraphManualZoom = .noZoom
    @MainActor var canvasZoomedOut: GraphManualZoom = .noZoom
    @MainActor var canvasJumpLocation: CGPoint? = nil
    
    @MainActor var nodeMenuHeight: CGFloat = INSERT_NODE_MENU_MAX_HEIGHT
    
    @MainActor var sidebarWidth: CGFloat = .zero // i.e. origin of graph from .global frame

    @MainActor var showCatalystProjectTitleModal: Bool = false
    
    // Only for node cursor selection box done when shift held
    @MainActor var nodesAlreadySelectedAtStartOfShiftNodeCursorBoxDrag: CanvasItemIdSet? = nil
    
    let propertySidebar = PropertySidebarObserver()
    
    @MainActor var lastMomentumRunTime: TimeInterval = .zero
    
    // e.g. user is hovering over or has selected a layer in the sidebar, which we then highlight in the preview window itself
    @MainActor var highlightedSidebarLayers: LayerIdSet = .init()

    @MainActor
    var edgeEditingState: EdgeEditingState?

    @MainActor var restartPrototypeWindowIconRotationZ: CGFloat = .zero

    // nil = no field focused
    @MainActor var reduxFocusedField: FocusedUserEditField?
    
    // set non-nil by up- and down-arrow key presses while an input's fields are focused
    // set nil after key press has been handled by `StitchTextEditingBindingField`
    @MainActor var reduxFocusedFieldChangedByArrowKey: FocusedFieldChangedByArrowKey?

    // Hack: to differentiate state updates that came from undo/redo (and which close the adjustment bar popover),
    // vs those that came from user manipulation of adjustment bar (which do not close the adjustment bar popover).
    @MainActor var adjustmentBarSessionId: UUID = .init()

    @MainActor var activelyEditedCommentBoxTitle: CommentBoxId?

    @MainActor var commentBoxBoundsDict = CommentBoxBoundsDict()

    @MainActor
    static let isPhoneDevice = Stitch.isPhoneDevice()

    @MainActor var edgeAnimationEnabled: Bool = false

    @MainActor var activeSpacebarClickDrag = false

    @MainActor var safeAreaInsets = SafeAreaInsetsEnvironmentKey.defaultValue
    @MainActor var colorScheme: ColorScheme = defaultColorScheme

    // Hackiness for handling option+drag "duplicate node and drag it"
    @MainActor var dragDuplication: Bool = false

    @MainActor var doubleTapLocation: CGPoint? {
        get {
            self.insertNodeMenuState.doubleTapLocation
        } set(newValue) {
            self.insertNodeMenuState.doubleTapLocation = newValue
        }
    }

    // which loop index to show
    @MainActor var activeIndex: ActiveIndex = ActiveIndex(0)

    // GRAPH: UI GROUPS AND LAYER PANELS
    // layer nodes (group or non-group) that have been selected
    // via the layer panel UI

    // Starts out as default value, but on first render of GraphView
    // we get the exact device screen size via GeometryReader.
    @MainActor var frame = DEFAULT_LANDSCAPE_GRAPH_FRAME

    // Note: our device-screen reading logic uses `.local` coordinate space and so does not detect that items in the graph actually sit a little lower on the screen.
    // TODO: better?: just always look at `.global`
    @MainActor var graphYPosition: CGFloat = .zero

    @MainActor var selection = GraphUISelectionState()

    // Control animation direction when group nodes are traversed
    @MainActor var groupTraversedToChild = false

    // Only applies to non-iPhones so that exiting full-screen mode goes
    // back to graph instead of projects list
    @MainActor var isFullScreenMode: Bool = false
    
    #if DEV_DEBUG
//    var showsLayerInspector = true   during dev
    @MainActor var showsLayerInspector = false // during dev
    #else
    @MainActor var showsLayerInspector = false
    #endif
    
    @MainActor var leftSidebarOpen = false

    // Tracks group breadcrumbs when group nodes are visited
    @MainActor var groupNodeBreadcrumbs: [GroupNodeType] = []

    @MainActor var showPreviewWindow = PREVIEW_SHOWN_DEFAULT_STATE

    @MainActor var insertNodeMenuState = InsertNodeMenuState()

    /*
     Similar to `activeDragInteraction`, but just for mouse nodes.
     - nil when LayerHoverEnded or LayerDragEnded
     - non-nil when LayerHovered or LayerDragged
     - when non-nil and it’s been more than `DRAG_NODE_VELOCITY_RESET_STEP` since last movement, reset velocity to `.zero`
     */
    @MainActor var lastMouseNodeMovement: TimeInterval?

    @MainActor var activeDragInteraction = ActiveDragInteractionNodeVelocityData()
    
    // tracks if sidebar is focused
    @MainActor var isSidebarFocused: Bool = false

    // Explicit `init` is required to use `didSet` on a property
    @MainActor
    init(activeSpacebarClickDrag: Bool = false,
         safeAreaInsets: SafeAreaInsets = SafeAreaInsetsEnvironmentKey.defaultValue,
         colorScheme: ColorScheme = defaultColorScheme,
         dragDuplication: Bool = false,
         doubleTapLocation: CGPoint? = nil,
         activeIndex: ActiveIndex = .defaultActiveIndex,
         frame: CGRect = DEFAULT_LANDSCAPE_GRAPH_FRAME,
         selection: GraphUISelectionState = .init(),
         groupTraversedToChild: Bool = false,
         isPhoneDevice: Bool,
         groupNodeBreadcrumbs: [GroupNodeType] = .init(),
         showPreviewWindow: Bool = PREVIEW_SHOWN_DEFAULT_STATE,
         insertNodeMenuState: InsertNodeMenuState = .init(),
         activeDragInteraction: ActiveDragInteractionNodeVelocityData = .init()) {

        self.activeSpacebarClickDrag = activeSpacebarClickDrag
        self.safeAreaInsets = safeAreaInsets
        self.colorScheme = colorScheme
        self.dragDuplication = dragDuplication
        self.doubleTapLocation = doubleTapLocation
        self.activeIndex = activeIndex
        self.frame = frame
        self.selection = selection
        self.groupTraversedToChild = groupTraversedToChild
        self.isFullScreenMode = isPhoneDevice
        self.groupNodeBreadcrumbs = groupNodeBreadcrumbs
        self.showPreviewWindow = showPreviewWindow
        self.insertNodeMenuState = insertNodeMenuState
        self.activeDragInteraction = activeDragInteraction
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func adjustedDoubleTapLocation(_ localPosition: CGPoint) -> CGPoint? {
        if let doubleTapLocation = self.graphUI.doubleTapLocation {
            return adjustPositionToMultipleOf(
                factorOutGraphOffsetAndScale(
                    location: doubleTapLocation,
                    graphOffset: localPosition,
                    graphScale: self.graphMovement.zoomData.zoom,
                    deviceScreen: self.graphUI.frame))
        }
        
        return nil
    }
}

extension GraphUIState {
    // If there's a group in focus
    @MainActor
    var groupNodeFocused: GroupNodeType? {
        self.groupNodeBreadcrumbs.last
    }
    
    @MainActor
    var isPortraitMode: Bool {
        #if targetEnvironment(macCatalyst)
        //        log("NEVER use portrait mode on macos")
        return false
        #else
        return frame.height > frame.width
        #endif
    }

    // Length for the sides of the 'GridTiling' square;
    // Should be the longest side (eg iPad portrait vs landscape)
    // and rounded to a multiple of grid square size.
    @MainActor
    var gridImageLength: CGFloat {
        let length = Int(max(frame.height,
                             frame.width))
            .roundedUp(toMultipleOf: SQUARE_SIDE_LENGTH)
        return CGFloat(length)
    }

    // A center that is aware of whether the sidebar is open or not;
    // used when inserting new nodes.
    // TODO: explore and formalize this concept;
    // ie this is "user-subjective center",
    // ie device screen center, but not same as `graphUI.frame`

    // TODO: Why do we adjust by localPosition?
    // See `ToggleAllSelectedNodes`
    // This is more like?: "the center of the NodesView",
    //    var center: CGPoint {
//    @MainActor
//    func center(_ localPosition: CGPoint,
//                graphScale: CGFloat) -> CGPoint {
//        var graphCenter = self.frame.getGraphCenter(localPosition: localPosition)
//
//        // Take left-sidebar into consideration
//        let sidebarAdjustment = (self.sidebarWidth/2 * 1/graphScale)
//        graphCenter.x -= sidebarAdjustment
//        
//        return graphCenter
//    }
}

extension GraphState {
    
    /// Returns  `NodeEntities` given some selection state. Recursively gets group children if group selected.
    @MainActor
    func getSelectedNodeEntities(for ids: NodeIdSet) -> [NodeEntity] {
        ids.flatMap { (nodeId: NodeId) -> [NodeEntity] in
                        
            guard let stitchViewModel: NodeViewModel = self.getNodeViewModel(nodeId) else {
                return []
            }
            
            let nodeSchema = stitchViewModel.createSchema()
            
            switch stitchViewModel.kind {
            case .group:
                // Recursively add nodes in node-ui-grouping
                let idsInGroup: NodeIdSet = self.visibleNodesViewModel
                    .getCanvasItems()
                    .filter { $0.parentGroupNodeId == stitchViewModel.id }
                    .compactMap { $0.id.nodeCase }
                    .toSet
                
                return [nodeSchema] + self.getSelectedNodeEntities(for: idsInGroup)
                
            case .layer(let layer) where layer == .group:
                // When we duplicate a LayerGroup, we must also duplicate its children.
                // Note that these children should have already been selected via the sidebar's selecton logic; but we can force that assumption here independently.
                guard let sidebarData = self.layersSidebarViewModel.items.get(nodeId),
                      let sidebarChildrenData = sidebarData.children else {
                    fatalErrorIfDebug()
                    return []
                }
                
                let allNestedChildren: [NodeEntity] = sidebarChildrenData.flattenedItems
                    .map(\.id)
                    .compactMap { id in
                        guard let node = self.getNodeViewModel(id) else {
                            fatalErrorIfDebug()
                            return nil
                        }
                        
                        return node.createSchema()
                    }

                return [nodeSchema] + allNestedChildren
                
            default:
                return [nodeSchema]
            }
        }
    }
    
    /// Resets various state including any alert state or graph selection state. Called after graph tap gesture or ESC key.
    @MainActor
    func resetAlertAndSelectionState() {

        #if !targetEnvironment(macCatalyst)
        // Fixes bug where keyboard may not disappear
        DispatchQueue.main.async {
            UIApplication.shared.dismissKeyboard()
        }
        #endif

        self.selectedEdges = .init()

        // if we tap the graph, we're no longer dragging either nodes or graph
        // TODO: should we also reset graphMovement.firstActive etc.? Otherwise we can get in an improper state?
        self.graphMovement.draggedCanvasItem = nil
        
        if self.graphMovement.graphIsDragged {
            self.graphMovement.graphIsDragged = false            
        }

        self.graphUI.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems()
        self.graphUI.insertNodeMenuState.searchResults = InsertNodeMenuState.allSearchOptions
        
        // TODO: should we just reset the entire insertNodeMenuState?
        withAnimation(.INSERT_NODE_MENU_TOGGLE_ANIMATION) {
            self.graphUI.insertNodeMenuState.show = false
            self.graphUI.insertNodeMenuState.doubleTapLocation = nil
        }
        
        self.graphUI.isFullScreenMode = false

        self.graphUI.activelyEditedCommentBoxTitle = nil

        // Wipe any redux-controlled focus field
        // (For now, just used with TextField layers)
        self.graphUI.reduxFocusedField = nil
        
        withAnimation {
            self.graphUI.showCatalystProjectTitleModal = false
        }
        
        self.graphUI.isSidebarFocused = false
    }
}

func adjustPositionToMultipleOf(_ position: CGPoint,
                                gridSideLength: Int = SQUARE_SIDE_LENGTH) -> CGPoint {

    let (prevMultipleWidth, nextMultipleWidth) = getMultiples(position.x, SQUARE_SIDE_LENGTH)

    let (prevMultipleHeight, nextMultipleHeight) = getMultiples(position.y, SQUARE_SIDE_LENGTH)

    let topDistance = abs(position.y - prevMultipleHeight)
    let bottomDistance = abs(position.y - nextMultipleHeight)

    // if topDistance is smaller, then move to the top grid line.
    let newY = topDistance < bottomDistance ? prevMultipleHeight : nextMultipleHeight

    let leftDistance = abs(position.x - prevMultipleWidth)
    let rightDistance = abs(position.x - nextMultipleWidth)

    // if leftDistance is smaller, then move to the left grid line.
    let newX = leftDistance < rightDistance ? prevMultipleWidth : nextMultipleWidth

    let newCenter = CGPoint(x: newX, y: newY)

    return newCenter
}

struct GraphUISelectionState {

    var selectedNodeIds = CanvasItemIdSet()
    var selectedCommentBoxes = CommentBoxIdSet()

    // TODO: turn selectedNodes into a list?
    // The last selected node,
    // (where we will display node tag)
    //    var lastSelectedNode: NodeId?

    // TODO: separate "selecting via tap or drag" from "selecting via selection box"

    // careful re: cross sync
    var isSelecting: Bool = false

    // if using finger-on-screen to create box,
    // then cursor should be larger than normal.
    var isFingerOnScreenSelection: Bool = false

    // Node cursor selection box
//    var expansionBox: CGRect?
    var expansionBox: ExpansionBox?

    // the start and current locations of the drag gesture
    var dragStartLocation: CGPoint?
    var dragCurrentLocation: CGPoint?

    var graphDragState = GraphDragState.none
}

enum GraphDragState: Codable {
    case none
    case dragging
}

extension GraphState {
        
    @MainActor
    func resetSelectedCanvasItems() {
        
        self.getCanvasItems().forEach {
            $0.deselect(self)
        }
    }
}

extension GraphUISelectionState {
    func resetSelectedCommentBoxes() -> Self {
        var state = self
        state.selectedCommentBoxes = .init()
        return state
    }
}

// When we tap or drag a single node,
// we thereby select.
extension GraphState {
    
    // Keep this helper around
    @MainActor
    func selectSingleNode(_ node: CanvasItemViewModel) {
        // ie expansionBox, isSelecting, selected-comments etc.
        // get reset when we select a single node.
        self.graphUI.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems()
        node.select(self)
    }
    
    @MainActor
    func deselectAllCanvasItems() {
        self.graphUI.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems()
    }
    
    @MainActor
    func selectSingleCanvasItem(_ canvasItem: CanvasItemViewModel) {
        // ie expansionBox, isSelecting, selected-comments etc.
        // get reset when we select a single canvasItem.
        self.deselectAllCanvasItems()
        canvasItem.select(self)
    }
    
    // TEST HELPER
    @MainActor
    func addNodeToSelections(_ nodeId: CanvasItemId) {
        guard let node = self.getCanvasItem(nodeId) else {
            fatalErrorIfDebug()
            return
        }
        node.select(self)
    }
}

extension CanvasItemViewModel {
    @MainActor
    func select(_ graph: GraphState) {
        log("CanvasItemViewModel: selecting called")
        // Prevent render cycles if already selected
        guard !self.isSelected  else { return }
        
        graph.graphUI.selection.selectedNodeIds.insert(self.id)
        
        // Unfocus sidebar
        graph.isSidebarFocused = false
    }
    
    @MainActor
    func deselect(_ graph: GraphState) {
        // Prevent render cycles if already unselected
        guard self.isSelected else { return }
        graph.graphUI.selection.selectedNodeIds.remove(self.id)
    }
}

// Model for graph zoom.
@Observable
final class GraphZoom {
    // Mouse wheel
    static let zoomScrollRate = 0.04
    
    // Shortcut
    static let zoomCommandRate = 0.1 // 0.25 // 0.175
    
    var final: CGFloat = 1

    var zoom: CGFloat {
        self.final
    }
}

enum GraphManualZoom: Equatable, Hashable, Codable {
    case noZoom,
         // different scroll rates: shortcut vs mouse wheel:
         shortcutKey,
         mouseWheel
    
    var zoomAmount: CGFloat? {
        switch self {
        case .noZoom:
            return nil
        case .shortcutKey:
            return GraphZoom.zoomCommandRate
        case .mouseWheel:
            return GraphZoom.zoomScrollRate
        }
    }
}


extension GraphState {
    @MainActor
    var selectedNodeIds: Set<CanvasItemId> {
        self.nodes.values
            .flatMap { node in
                node.getAllCanvasObservers()
                    .compactMap { canvas in
                        guard canvas.isSelected else {
                            return nil
                        }
                        return canvas.id
                    }
            }
            .toSet
    }
}

extension GraphState {
    @MainActor
    var selectedCanvasItems: CanvasItemViewModels {
        self.getVisibleCanvasItems().filter(\.isSelected)
    }
    
    @MainActor
    var selectedCanvasLayerItemIds: [LayerNodeId] {
        self.selectedCanvasItems
            .filter(\.id.isForLayer)
            .map(\.id.associatedNodeId.asLayerNodeId)
    }
}

//
//  GraphUI.swift
//  prototype
//
//  Created by Elliot Boschwitz on 10/10/21.
//

import SwiftUI
import StitchSchemaKit

// MARK: where we can store canvas ui data

// Addresses to specific fields in an unpacked multifield layer node input
enum LayerFields {
    case position(LayerFieldsPosition)
    case size(LayerFieldsSize)
    case dropShadow(LayerFieldsDropShadow)
}

enum LayerFieldsPosition {
    case x, y
}

enum LayerFieldsSize {
    case width, height
}

enum LayerFieldsDropShadow {
    case x, y, blur, radius
}

enum _CanvasItemId {
    // patch node
    case node(NodeId)
    
    // e.g. scale, rotation x, rotation y, packed size, packed position
    case layerInput(nodeId: NodeId, input: LayerInputType)
    
    // e.g. unpacked size, unpacked position
    case layerField(nodeId: NodeId, address: LayerFields)
}

struct LayerRowData {
    let rowObserver: NodeRowObserver
    
    // i.e. This layer node input has either:
    // - no canvas items at all, or
    // - one canvas item, or
    // - n-many canvas items (each optional)
    let canvasObservers: LayerRowCanvas?
    
    // i.e. for this given layer node input, get the canvas ui item
    func getCanvasObserver(id: _CanvasItemId) -> CanvasItemViewModel? {
        self.canvasObservers?.getCanvasObserver(id: id)
    }
}

// "1 address = 1 canvas ui data (optional)" feels correct; we're capturing the fact that
enum LayerRowCanvas {
    // e.g. color, corner radius, packed size, packed position etc.
    case single(CanvasItemViewModel)
    
    // unpacked size, unpacked position
    case two(x: CanvasItemViewModel?,
             y: CanvasItemViewModel?)
    
    // unpacked point3D
    case three(x: CanvasItemViewModel?,
               y: CanvasItemViewModel?,
               z: CanvasItemViewModel?)
    
    // unpacked padding, unpacked dropshadow; can choose different names, or use a totally separate case
    // can use generic parameters (below works well for Point4D) ...
    case four(x: CanvasItemViewModel?,
              y: CanvasItemViewModel?,
              z: CanvasItemViewModel?,
              w: CanvasItemViewModel?)
    
    // ... or additional, more specific cases:
    case dropshadow(x: CanvasItemViewModel?,
                    y: CanvasItemViewModel?,
                    blur: CanvasItemViewModel?,
                    radius: CanvasItemViewModel?)
    
    func getCanvasObserver(id: _CanvasItemId) -> CanvasItemViewModel? {
        
        switch id {
            
        case .layerInput:
            return self.getSingle()
            
        case .layerField(nodeId: let nodeId, address: let field):
            
            // The mapping of unique addresses to numerically-counted Feels a bit verbose / redundant ?
            switch field {
                
            case .position(let layerFieldsPosition):
                switch layerFieldsPosition {
                case .x:
                    return self.getTwoX()
                case .y:
                    return self.getTwoY()
                }
                
            case .size(let layerFieldsSize):
                switch layerFieldsSize {
                case .width:
                    return self.getTwoX()
                case .height:
                    return self.getTwoY()
                }
                
            case .dropShadow(let layerFieldsDropShadow):
                switch layerFieldsDropShadow {
                case .x:
                    return self.getDropshadowX()
                case .y:
                    return self.getDropshadowY()
                case .blur:
                    return self.getDropshadowBlur()
                case .radius:
                    return self.getDropshadowRadius()
                }
                
            default:
                fatalError()
            } // switch address
            
        default:
            fatalError()
        } // switch id
        
    }
    
}

// Helpers; we only write these once, and only for (potentially) multifield layer inputs
extension LayerRowCanvas {
    
    func getSingle() -> CanvasItemViewModel? {
        switch self {
        case .single(let x):
            return x
        default:
            return nil
        }
    }
    
    func getTwoX() -> CanvasItemViewModel? {
        switch self {
        case .two(let x, let y):
            return x
        default:
            return nil
        }
    }
    
    func getTwoY() -> CanvasItemViewModel? {
        switch self {
        case .two(let x, let y):
            return y
        default:
            return nil
        }
    }
    
    func getThreeX() -> CanvasItemViewModel? {
        switch self {
        case .three(let x, let y, let z):
            return x
        default:
            return nil
        }
    }
    
    func getThreeY() -> CanvasItemViewModel? {
        switch self {
        case .three(let x, let y, let z):
            return y
        default:
            return nil
        }
    }
    
    func getThreeZ() -> CanvasItemViewModel? {
        switch self {
        case .three(let x, let y, let z):
            return z
        default:
            return nil
        }
    }
    
    func getDropshadowX() -> CanvasItemViewModel? {
        switch self {
        case .dropshadow(x: let x, y: let y, blur: let blur, radius: let radius):
            return x
        default:
            return nil
        }
    }
    
    func getDropshadowY() -> CanvasItemViewModel? {
        switch self {
        case .dropshadow(x: let x, y: let y, blur: let blur, radius: let radius):
            return y
        default:
            return nil
        }
    }
    
    func getDropshadowBlur() -> CanvasItemViewModel? {
        switch self {
        case .dropshadow(x: let x, y: let y, blur: let blur, radius: let radius):
            return blur
        default:
            return nil
        }
    }
    
    func getDropshadowRadius() -> CanvasItemViewModel? {
        switch self {
        case .dropshadow(x: let x, y: let y, blur: let blur, radius: let radius):
            return radius
        default:
            return nil
        }
    }
}


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

@Observable
final class GraphUIState {
        
    var propertySidebar = PropertySidebarState()
    
    var llmRecording = LLMRecordingState()
        
    var nodesThatWereOnScreenPriorToEnteringFullScreen = NodeIdSet()
    
    var lastMomentumRunTime: TimeInterval = .zero
    
    // e.g. user is hovering over or has selected a layer in the sidebar, which we then highlight in the preview window itself
    var highlightedSidebbarLayers: LayerIdSet = .init()

    var edgeEditingState: EdgeEditingState?

    var restartPrototypeWindowIconRotationZ: CGFloat = .zero

    // nil = no field focused
    var reduxFocusedField: FocusedUserEditField?

    // Hack: to differentiate redux updates that came from undo/redo (and which close the adjustment bar popover),
    // vs those that came from user manipulation of adjustment bar (which do not close the adjustment bar popover).
    var adjustmentBarSessionId: AdjustmentBarSessionId = .init(id: .init())

    var activelyEditedCommentBoxTitle: CommentBoxId?

    var commentBoxBoundsDict = CommentBoxBoundsDict()

    @MainActor
    static let isPhoneDevice = Stitch.isPhoneDevice()

    var edgeAnimationEnabled: Bool = false

    var activeSpacebarClickDrag = false

    var safeAreaInsets = SafeAreaInsetsEnvironmentKey.defaultValue
    var colorScheme: ColorScheme = defaultColorScheme

    // Hackiness for handling option+drag "duplicate node and drag it"
    var dragDuplication: Bool = false

    var doubleTapLocation: CGPoint?

    var keypressState = KeyPressState()

    // which loop index to show
    var activeIndex: ActiveIndex = ActiveIndex(0)

    // GRAPH: UI GROUPS AND LAYER PANELS
    // layer nodes (group or non-group) that have been selected
    // via the layer panel UI

    // Starts out as default value, but on first render of GraphView
    // we get the exact device screen size via GeometryReader.
    var frame = DEFAULT_LANDSCAPE_GRAPH_FRAME

    var selection = GraphUISelectionState()

    // If there's a group in focus
    var groupNodeFocused: GroupNodeId?

    // Control animation direction when group nodes are traversed
    var groupTraversedToChild = false

    // Only applies to non-iPhones so that exiting full-screen mode goes
    // back to graph instead of projects list
    @MainActor
    var isFullScreenMode: Bool = GraphUIState.isPhoneDevice
    
    #if DEV_DEBUG
    var showsLayerInspector = true // during dev
//        var showsLayerInspector = false // during dev
    #else
    var showsLayerInspector = false
    #endif

    // Tracks group breadcrumbs when group nodes are visited
    var groupNodeBreadcrumbs: NodeIdList = []

    var showPreviewWindow = PREVIEW_SHOWN_DEFAULT_STATE

    var insertNodeMenuState = InsertNodeMenuState()

    /*
     Similar to `activeDragInteraction`, but just for mouse nodes.
     - nil when LayerHoverEnded or LayerDragEnded
     - non-nil when LayerHovered or LayerDragged
     - when non-nil and it’s been more than `DRAG_NODE_VELOCITY_RESET_STEP` since last movement, reset velocity to `.zero`
     */
    var lastMouseNodeMovement: TimeInterval?

    var activeDragInteraction = ActiveDragInteractionNodeVelocityData()

    // Explicit `init` is required to use `didSet` on a property
    @MainActor
    init(activeSpacebarClickDrag: Bool = false,
         safeAreaInsets: SafeAreaInsets = SafeAreaInsetsEnvironmentKey.defaultValue,
         colorScheme: ColorScheme = defaultColorScheme,
         dragDuplication: Bool = false,
         doubleTapLocation: CGPoint? = nil,
         keypressState: KeyPressState = .init(),
         activeIndex: ActiveIndex = .defaultActiveIndex,
         frame: CGRect = DEFAULT_LANDSCAPE_GRAPH_FRAME,
         selection: GraphUISelectionState = .init(),
         groupNodeFocused: GroupNodeId? = nil,
         groupTraversedToChild: Bool = false,
         isFullScreenMode: Bool = GraphUIState.isPhoneDevice,
         groupNodeBreadcrumbs: NodeIdList = .init(),
         showPreviewWindow: Bool = PREVIEW_SHOWN_DEFAULT_STATE,
         insertNodeMenuState: InsertNodeMenuState = .init(),
         activeDragInteraction: ActiveDragInteractionNodeVelocityData = .init()) {

        self.activeSpacebarClickDrag = activeSpacebarClickDrag
        self.safeAreaInsets = safeAreaInsets
        self.colorScheme = colorScheme
        self.dragDuplication = dragDuplication
        self.doubleTapLocation = doubleTapLocation
        self.keypressState = keypressState
        self.activeIndex = activeIndex
        self.frame = frame
        self.selection = selection
        self.groupNodeFocused = groupNodeFocused
        self.groupTraversedToChild = groupTraversedToChild
        self.isFullScreenMode = isFullScreenMode
        self.groupNodeBreadcrumbs = groupNodeBreadcrumbs
        self.showPreviewWindow = showPreviewWindow
        self.insertNodeMenuState = insertNodeMenuState
        self.activeDragInteraction = activeDragInteraction
    }
}

extension GraphState {
    @MainActor
    func adjustedDoubleTapLocation(_ localPosition: CGPoint) -> CGPoint? {
        self.graphUI.doubleTapLocation.map {
            adjustPositionToMultipleOf(
                factorOutGraphOffsetAndScale(
                    location: $0,
                    graphOffset: localPosition,
                    graphScale: self.graphMovement.zoomData.zoom,
                    deviceScreen: self.graphUI.frame))
        }
    }
}

extension GraphUIState {
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
    @MainActor
    func center(_ localPosition: CGPoint) -> CGPoint {
        self.frame.getGraphCenter(localPosition: localPosition)
    }
}

extension GraphState {
    
    @MainActor
    func getSelectedNodeViewModels() -> NodeViewModels {
        self.nodes.values.filter {
            $0.isSelected
        }
    }

    /// Returns  `NodeEntities` given some selection state. Recursively gets group children if group selected.
    @MainActor
    func getSelectedNodeEntities(for ids: NodeIdSet) -> NodeEntities {
        ids.flatMap { nodeId -> NodeEntities in
            guard let nodeViewModel = self.getNodeViewModel(nodeId) else {
                return []
            }
            
            let nodeSchema = nodeViewModel.createSchema()
            
            switch nodeViewModel.kind {
            case .group:
                // Recursively add nodes in group
                let idsInGroup = self.nodes.values
                    .filter { $0.parentGroupNodeId == nodeViewModel.id }
                    .map { $0.id }
                    .toSet
                
                return [nodeSchema] + getSelectedNodeEntities(for: idsInGroup)
                
            case .layer(let layer) where layer == .group:
                // Recursively add layer nodes in layer group
                let idsInLayerGroup = self.nodes.values
                    .filter { $0.layerNode?.layerGroupId == nodeViewModel.id }
                    .map { $0.id }
                    .toSet
                
                return [nodeSchema] + getSelectedNodeEntities(for: idsInLayerGroup)
                
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
        self.graphMovement.graphIsDragged = false

        self.graphUI.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems()
        self.graphUI.insertNodeMenuState.searchResults = InsertNodeMenuState.allSearchOptions
        self.graphUI.insertNodeMenuState.show = false
        self.graphUI.isFullScreenMode = false

        self.graphUI.activelyEditedCommentBoxTitle = nil

        // Wipe any redux-controlled focus field
        // (For now, just used with TextField layers)
        self.graphUI.reduxFocusedField = nil
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

struct GraphUISelectionState: Equatable, Codable, Hashable {

    // Selected comment boxes
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
    var expansionBox = ExpansionBox()

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
            $0.deselect()
        }

        // // bad: needs to be
//        self.nodes.values.forEach { node in
//            switch node.kind {
//            case .layer:
//                node.inputRowObservers().forEach { $0.canvasUIData?.deselect() }
//                node.outputRowObservers().forEach { $0.canvasUIData?.deselect() }
//            case .patch, .group:
//                node.deselect()
//            }
//        }
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
    func selectSingleNode(_ node: NodeViewModel) {
        // ie expansionBox, isSelecting, selected-comments etc.
        // get reset when we select a single node.
        self.graphUI.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems()
        node.select()
    }
    
    @MainActor
    func selectSingleCanvasItem(_ canvasItem: CanvasItemViewModel) {
        // ie expansionBox, isSelecting, selected-comments etc.
        // get reset when we select a single canvasItem.
        self.graphUI.selection = GraphUISelectionState()
        self.resetSelectedCanvasItems()
        canvasItem.select()
    }
    
    // TEST HELPER
    @MainActor
    func addNodeToSelections(_ nodeId: NodeId) {
        guard let node = self.getNode(nodeId) else {
            fatalErrorIfDebug()
            return
        }
        node.select()
    }
}

extension NodeViewModel {
    @MainActor
    func select() {
        self.isSelected = true
    }
    
    @MainActor
    func deselect() {
        self.isSelected = false
    }
}

extension CanvasItemViewModel {
    @MainActor
    func select() {
        self.isSelected = true
    }
    
    @MainActor
    func deselect() {
        self.isSelected = false
    }
}

// Model for graph zoom.
struct GraphZoom: Equatable, Codable, Hashable {
    var current: CGFloat = 0
    var final: CGFloat = 1

    var zoom: CGFloat {
        self.current + self.final
    }
}

extension GraphState {
    @MainActor
    var selectedNodeIds: NodeIdSet {
        self.nodes.values
            .compactMap {
                if $0.isSelected {
                    return $0.id
                }
                return nil
            }
            .toSet
    }
}

extension GraphState {
    @MainActor
    var selectedCanvasItems: CanvasItemViewModels {
        self.getVisibleCanvasItems().filter(\.isSelected)
    }
}

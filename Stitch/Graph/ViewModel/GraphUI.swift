//
//  GraphUI.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/10/21.
//

import SwiftUI
import StitchSchemaKit
import UIKit

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

extension StitchDocumentViewModel {
    @MainActor
    func adjustedDoubleTapLocation(_ localPosition: CGPoint) -> CGPoint? {
        if let doubleTapLocation = self.insertNodeMenuState.doubleTapLocation {
            return adjustPositionToMultipleOf(
                factorOutGraphOffsetAndScale(
                    location: doubleTapLocation,
                    graphOffset: localPosition,
                    graphScale: self.graphMovement.zoomData,
                    deviceScreen: self.frame))
        }
        
        return nil
    }
}

extension StitchDocumentViewModel {
    
    // If there's a group in focus
    @MainActor
    var groupNodeFocused: GroupNodeType? {
        self.groupNodeBreadcrumbs.last
    }
    
    @MainActor
    var doubleTapLocation: CGPoint? {
        self.insertNodeMenuState.doubleTapLocation
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
    func resetAlertAndSelectionState(document: StitchDocumentViewModel) {

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

        if self.selection != GraphUISelectionState.zero {
            self.selection = GraphUISelectionState()
        }
        
        self.resetSelectedCanvasItems()
        document.insertNodeMenuState.searchResults = InsertNodeMenuState.allSearchOptions
        
        // TODO: should we just reset the entire insertNodeMenuState?
        withAnimation(.INSERT_NODE_MENU_TOGGLE_ANIMATION) {
            document.insertNodeMenuState.show = false
            document.insertNodeMenuState.doubleTapLocation = nil
        }
        
        document.isFullScreenMode = false

        self.activelyEditedCommentBoxTitle = nil

        // Wipe any redux-controlled focus field
        // (For now, just used with TextField layers)
        if document.reduxFocusedField != nil {
            document.reduxFocusedField = nil
        }
        
        withAnimation {
            document.showCatalystProjectTitleModal = false
        }
        
        if self.layersSidebarViewModel.isSidebarFocused {
            self.layersSidebarViewModel.isSidebarFocused = false
        }
        
        if document.openPortPreview != nil {
            document.openPortPreview = nil
        }
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

struct GraphUISelectionState: Equatable {
    static let zero = GraphUISelectionState()

    var selectedCanvasItems = CanvasItemIdSet()
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
    
    @MainActor
    func selectSingleCanvasItem(_ canvasItemId: CanvasItemId) {
        // ie expansionBox, isSelecting, selected-comments etc.
        // get reset when we select a single canvasItem.
        self.resetSelectedCanvasItems()
        self.selectCanvasItem(canvasItemId)
    }
    
    @MainActor
    func resetSelectedCanvasItems() {
        if self.selection != .zero {
            self.selection = GraphUISelectionState()
        }
        self.getCanvasItems().forEach {
            self.deselectCanvasItem($0.id)
        }
    }
  
    /*
     Note: previously this logic was a method on `CanvasItemViewModel` that took a full `GraphState`.
     
     However, such a signature misleadingly implied that selection-status was stored on the canvas item itself, like canvas item's z-index.
     We were also forced to retrieve the full canvas item view model in contexts where we only had, and only needed, the canvas item's id.
     
     This new signature `(GraphState, CanvasItemId) -> Void` makes clear that we're modifying (part of) GraphState and only need the canvas item id.
     */
    @MainActor
    func selectCanvasItem(_ canvasItemId: CanvasItemId) {
        // Prevent render cycles if already selected
        guard !self.isCanvasItemSelected(canvasItemId) else { return }
        self.selection.selectedCanvasItems.insert(canvasItemId)
        
        // Unfocus sidebar
        if self.layersSidebarViewModel.isSidebarFocused {
            self.layersSidebarViewModel.isSidebarFocused = false
        }
    }
    
    // TODO: signature could be tighter, e.g. method on `SelectionState` rather than `GraphState`
    @MainActor
    func deselectCanvasItem(_ canvasItemId: CanvasItemId) {
        guard self.isCanvasItemSelected(canvasItemId) else { return }
        self.selection.selectedCanvasItems.remove(canvasItemId)
    }
    
    @MainActor
    func isCanvasItemSelected(_ canvasItemId: CanvasItemId) -> Bool {
        self.selection.selectedCanvasItems.contains(canvasItemId)
    }
}

// TODO: probably doesn't need to be a class anymore? Can just be a proe

// Mouse wheel
let MOUSE_WHEEL_ZOOM_SCROLL_RATE = 0.04

// Shortcut
let SHORTCUT_COMMAND_ZOOM_RATE = 0.1 // 0.25 // 0.175

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
            return SHORTCUT_COMMAND_ZOOM_RATE
        case .mouseWheel:
            return MOUSE_WHEEL_ZOOM_SCROLL_RATE
        }
    }
}


extension GraphState {
    @MainActor
    var selectedCanvasItems: Set<CanvasItemId> {
        self.nodes.values
            .flatMap { node in
                node.getAllCanvasObservers()
                    .compactMap { canvas in
                        guard self.isCanvasItemSelected(canvas.id) else {
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
    func getSelectedCanvasItems(groupNodeFocused: NodeId?) -> CanvasItemViewModels {
        self.getCanvasItemsAtTraversalLevel(groupNodeFocused: groupNodeFocused)
            .filter { self.isCanvasItemSelected($0.id) }
    }
    
    @MainActor
    func getSelectedCanvasLayerItemIds(groupNodeFocused: NodeId?) -> [LayerNodeId] {
        self.getSelectedCanvasItems(groupNodeFocused: groupNodeFocused)
            .filter(\.id.isForLayer)
            .map(\.id.associatedNodeId.asLayerNodeId)
    }
}

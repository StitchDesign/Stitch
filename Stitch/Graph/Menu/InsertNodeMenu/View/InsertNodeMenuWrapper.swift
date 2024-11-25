//
//  InsertNodeMenuWrapper.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/19/24.
//

import Foundation
import SwiftUI

struct InsertNodeMenuWrapper: View {
    static let menuWidth: CGFloat = INSERT_NODE_MENU_WIDTH
    static let opacityAnimationDelay: Double = 0.25
    static let shownMenuScale: CGFloat = 1
    
    // let opacity animation last a tiny bit longer
    static let opacityAnimationDuration = Self.scaleAnimationDuration - Self.opacityAnimationDelay/2

    static let opacityAnimation = Animation
        .linear(duration: opacityAnimationDuration)
        .delay(Self.opacityAnimationDelay)
    
    static let scaleAnimationDuration: Double = 0.4
    static let scaleAnimation = Animation.linear(duration: scaleAnimationDuration)

    // These values set in onAppear and when insertion animation completes
    @State private var nodeOpacity: CGFloat = .zero

    @State private var menuScaleX: CGFloat = .zero
    @State private var menuScaleY: CGFloat = .zero

    @State private var nodeScaleX: CGFloat = .zero
    @State private var nodeScaleY: CGFloat = .zero

    @State private var menuPosition: CGPoint = .zero
    @State private var nodePosition: CGPoint = .zero

    // doesn't really matter, since overridden by actual node size
    @State private var nodeWidth: CGFloat = 300.0
    @State private var nodeHeight: CGFloat = 200.0
    @State private var animatedNode: NodeViewModel?

    @Bindable var document: StitchDocumentViewModel
    @Bindable var graphUI: GraphUIState
    
    var menuHeight: CGFloat {
        graphUI.nodeMenuHeight
    }
    
    // TODO: add back or fully remove when we reintroduce
    //    @Binding var screenSize: CGSize
    
    var graphScale: CGFloat {
        graphMovement.zoomData.zoom
    }
    
    // menu and animating-node start in middle
    var menuOrigin: CGPoint {
        CGPoint(x: screenWidth/2,
                y: screenHeight/2)
    }

    var screenWidth: CGFloat {
         graphUI.frame.width
//        self.screenSize.width
    }

    var screenHeight: CGFloat {
         graphUI.frame.height
//        self.screenSize.height
    }
    
    private var graphMovement: GraphMovementObserver {
        self.document.graphMovement
    }
    
    // GraphUI properties
    var insertNodeMenuState: InsertNodeMenuState {
        graphUI.insertNodeMenuState
    }

    // `showMenu: false` = animate from menu to node
    var showMenu: Bool {
        !graphUI.insertNodeMenuState.menuAnimatingToNode
    }

    static let shownMenuCornerRadius: CGFloat = 16
    //    static let hiddenMenuCornerRadius: CGFloat = 98
    static let hiddenMenuCornerRadius: CGFloat = 60

    @State var menuCornerRadius: CGFloat = Self.shownMenuCornerRadius

    // We show the modal background when menu is toggled but node-animation has not yet started
    var showModalBackground: Bool {
        graphUI.insertNodeMenuState.show
            && !graphUI.insertNodeMenuState.menuAnimatingToNode
    }

    var menuAnimatingToNode: Bool {
        graphUI.insertNodeMenuState.menuAnimatingToNode
    }
    
    @MainActor
    func getNodeDestination() -> CGPoint {
        
        let adjustedDoubleTapLocation = document.adjustedDoubleTapLocation(document.visibleGraph.localPosition)
        
        var defaultCenter = document.graphUI.center(
            document.visibleGraph.localPosition,
            graphScale: self.graphScale)
        
        let sidebarAdjustment = 0.0 //(self.sidebarHalfWidth * 1/self.graphScale)
        
//        if document.llmRecording.isRecording {
//            return defaultCenter
//        } else
        if var adjustedDoubleTapLocation = adjustedDoubleTapLocation {
            adjustedDoubleTapLocation.x += sidebarAdjustment
            return adjustedDoubleTapLocation
        } else {
            // add back the half sidebar width?
            defaultCenter.x += sidebarAdjustment
            return defaultCenter
        }
    }
    
    // i.e. placing the menu in the center of the screen again;
    // done whenever view first appears, or we change menuOrigin (due to screen-resizing from on-screen keyboard)
    func prepareHiddenMenu(setHeightToMax: Bool = true) {
        // log("prepareHiddenMenu called: menuOrigin: \(menuOrigin)")

        self.menuCornerRadius = Self.shownMenuCornerRadius

        self.nodeOpacity = .zero
        self.menuScaleX = Self.shownMenuScale
        self.menuScaleY = Self.shownMenuScale

        self.nodeScaleX = self.getLargeNodeWidthScale()
        self.nodeScaleY = self.getLargeNodeHeightScale()

        // menu and animating-node start out in center of screen
        self.menuPosition = menuOrigin

        // Need to factor out graph offset, to get node placed under the menu
        self.nodePosition = self.getAdjustedMenuOrigin() // menuOrigin

        if setHeightToMax {
//            self.menuHeight = INSERT_NODE_MENU_MAX_HEIGHT
            dispatch(NodeMenuHeightSet(newHeight: INSERT_NODE_MENU_MAX_HEIGHT))
        }
    }
    
    func getLargeNodeWidthScale() -> CGFloat {
        Self.menuWidth / self.nodeWidth * (1 / graphScale)
    }
    
    func getLargeNodeHeightScale() -> CGFloat {
        self.nodeHeight / menuHeight * graphScale
    }
    
    @MainActor
    func animateNode() {
        // factor out the graphScale,
        // since now the node needs to look like the menu
        let largeNodeWidthScale: CGFloat = self.getLargeNodeWidthScale()
        
        let largeNodeHeightScale: CGFloat = self.getLargeNodeHeightScale()

        withAnimation(Self.opacityAnimation) {
            nodeOpacity = showMenu ? 0 : 1
        }

        withAnimation(Self.scaleAnimation) {

            // Adjust the corner radius when menu hidden
            menuCornerRadius = showMenu ? Self.shownMenuCornerRadius : Self.hiddenMenuCornerRadius

            // Menu's opacity does not actually change during animation;
            // we merely let the node appear over it (z-index)

            nodeScaleX = showMenu ? largeNodeWidthScale : 1
            nodeScaleY = showMenu ? largeNodeHeightScale : 1

            // Node's hidden position = menu position + graph offset factored OUT
            nodePosition = showMenu ? getAdjustedMenuOrigin() : getNodeDestination()
        }
    }
    
    var graphOffset: CGPoint {
        graphMovement.localPosition
    }

    // Used by node-view only
    func getAdjustedMenuOrigin() -> CGPoint {
        // When the menu is shown and the node is hidden,
        // the node needs to be positioned directly underneath the menu;
        // since the node (but not the menu) is affected by graph offset,
        // we need to factor graph offset out of the menuOrigin the node will be using.
        var d = menuOrigin
        d.x -= graphOffset.x
        d.y -= graphOffset.y
        return d
    }
    
    @MainActor
    func animateMenu() {
        let graphOffset: CGSize = graphMovement.localPosition.toCGSize
        let graphScale: CGFloat = graphMovement.zoomData.zoom
        let nodeDestination = self.getNodeDestination()
        
        // factor in the graphScale,
        // since now the menu needs to look like the node
        let smallMenuWidthScale: CGFloat = nodeWidth/Self.menuWidth * graphScale
        
        //        nodeHeight/Self.menuHeight * graphScale
        let smallMenuHeightScale: CGFloat = nodeHeight/menuHeight * graphScale

        withAnimation(Self.scaleAnimation) {
            menuScaleX = showMenu ? Self.shownMenuScale : smallMenuWidthScale
            menuScaleY = showMenu ? Self.shownMenuScale : smallMenuHeightScale

            // node destination's diff from center
            let diffX = screenWidth/2 - nodeDestination.x

            //            let diffY = screenHeight/2 - nodeDestination.height

            // Use non-changing height of screen for menu's animation-end position;
            // i.e. animate the menu to a position as if the keyboard were not on screen.
            let diffY = graphUI.frame.size.height/2 - nodeDestination.y

            let finalDiffX = diffX * (1 - graphScale)
            let finalDiffY = diffY * (1 - graphScale)

            let scaledOffsetWidth = graphOffset.width * graphScale
            let scaledOffsetHeight = graphOffset.height * graphScale

            let menuHiddenPositionX = nodeDestination.x
                + finalDiffX
                + scaledOffsetWidth

            let menuHiddenPositionY = nodeDestination.y
                + finalDiffY
                + scaledOffsetHeight
            
            let menuHiddenPosition = CGPoint(x: menuHiddenPositionX,
                                             y: menuHiddenPositionY)

            menuPosition = showMenu
                ? menuOrigin
                : menuHiddenPosition
        } // withAnimation

    }
    
    /*
     Two uses of NodeView by node menu:
    
     1. reading the size of the node, before animation starts: `boundsDisabled = false`, `updateMenuActiveSelectionBounds = true`
     
     2. animating the node, using the read animation starts: `boundsDisabled = false`, `updateMenuActiveSelectionBounds = true`
     */
    @MainActor @ViewBuilder
    func fakeNodeView(boundsDisabled: Bool,
                      updateMenuActiveSelectionBounds: Bool) -> some View {

        if let node = self.animatedNode,
           let canvas = node.patchCanvasItem {
            @Bindable var canvas = canvas
            NodeTypeView(document: document,
                         graph: document.visibleGraph,
                         node: node,
                         canvasNode: canvas,
                         atleastOneCommentBoxSelected: false,
                         activeIndex: .init(1),
                         groupNodeFocused: nil,
                         adjustmentBarSessionId: .fakeId,
                         isSelected: false,
                         boundsReaderDisabled: boundsDisabled,
                         // fake node does NOT use position handler
                         usePositionHandler: false,
                         updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds)
            .onChange(of: canvas.sizeByLocalBounds) { _, newSize in
                guard let newSize = newSize,
                      newSize.width.isNormal && newSize.height.isNormal else { return }
                
                self.nodeWidth = newSize.width
                self.nodeHeight = newSize.height
                
                prepareHiddenMenu(setHeightToMax: false)
            }
        } // if let nodeType =
        else {
            EmptyView()
        }
    }

    var menuView: some View {
        // InsertNodeMenu should NOT ignore the .keyboard and/or .bottom safe areas
        // however, GeometryReader (used for determining preview window size) SHOULD;
        // so, we need to apply the InsertNodeMenu SwiftUI .modifier after we've ignored safe areas.
        InsertNodeMenuView(
            cornerRadius: $menuCornerRadius,
            insertNodeMenuState: insertNodeMenuState,
            isPortraitMode: document.previewWindowSize.isPortrait,
            showMenu: insertNodeMenuState.show,
            menuHeight: menuHeight,
            animatingNodeOpacity: self.nodeOpacity)
        
            // scale first, THEN position
//            .scaleEffect(x: menuScaleX, y: menuScaleY)
            // use .position modifier to match node's use of .position modifier
//            .position(menuPosition)
//            .offset(x: -sidebarHalfWidth)
    }
    
    // should be subtracted
//    var sidebarHalfWidth: CGFloat {
//        graphUI.sidebarWidth/2
//    }
    
    var body: some View {
        ZStack {

            
#if DEV_DEBUG || DEBUG
            let pseudoPopoverBackgroundOpacity = 0.1
#else
            let pseudoPopoverBackgroundOpacity = 0.001
#endif
            
            ModalBackgroundGestureRecognizer(dismissalCallback: { dispatch(CloseAndResetInsertNodeMenu()) }) {
//                Color.blue.opacity(pseudoPopoverBackgroundOpacity)
                Color.clear
            }
//            .opacity(showModalBackground ? 1 : 0)
            
            // Insert Node Menu view
            if graphUI.insertNodeMenuState.show {
                menuView
                .shadow(radius: 4)
                .shadow(radius: 8, x: 4, y: 2)
                    .animation(.default, value: graphUI.insertNodeMenuState.show)
            }
                        
//            // NodeView used only for animation; does not read size,
//            // since its size changes during animation.
//            // Note: don't render this NodeView until we have committed our choice.
//            if graphUI.insertNodeMenuState.menuAnimatingToNode {
//                animatedNodeView
//                    .opacity(graphUI.insertNodeMenuState.show ? 1 : 0)
//                    .onChange(of: graphUI.insertNodeMenuState.show) {
//                        // Surfacing the menu may cause the responder chain to break, causing key modifiers
//                        // to lose tracking for end state
//                        dispatch(KeyModifierReset())
//                    }
////                    .offset(x: -sidebarHalfWidth)
//            }
        }
        .onAppear {
            //            log("onAppear")

            // default, but also updated when GeometryReader changes
            //            self.screenHeight = graphUI.frame.height
            prepareHiddenMenu()
        }
        .onChange(of: self.menuOrigin, initial: true) { _, _ in
            //            log("ContentView: onChange of menuOrigin: oldValue: \(oldValue)")
            //            log("ContentView: onChange of menuOrigin: newValue: \(newValue)")
            // don't change during animation
            if !graphUI.insertNodeMenuState.menuAnimatingToNode {
                prepareHiddenMenu(setHeightToMax: false)
            }
        }
//        .onChange(of: self.screenSize, initial: true) { _, _ in
//            //            log("ContentView: onChange of self.screenSize: oldValue: \(oldValue)")
//            //            log("ContentView: onChange of self.screenSize: newValue: \(newValue)")
//            if !graphUI.insertNodeMenuState.menuAnimatingToNode {
//                prepareHiddenMenu(setHeightToMax: false)
//            }
//        }
        .onChange(of: graphUI.insertNodeMenuState.menuAnimatingToNode, initial: true) { _, newValue in
            // log("ContentView: onChange of menuAnimatingToNode: oldValue: \(oldValue)")
            // log("ContentView: onChange of menuAnimatingToNode: newValue: \(newValue)")

            // Only fire these when animating = true and the menu toggle status = open
            if newValue && graphUI.insertNodeMenuState.show {
                animateMenu()
                animateNode()
            }
            // When animation completes, reset menu state
            if !newValue {
                prepareHiddenMenu()
            }
        }
        // Keeping the local state `animatedNode` up to date with our activeSelection.
        .onChange(of: graphUI.insertNodeMenuState.activeSelection, initial: true) { _, _ in
            //            log("ContentView: onChange of activeSelection: oldValue: \(oldValue)")
            //            log("ContentView: onChange of activeSelection: newValue: \(newValue)")
            self.animatedNode = graphUI.insertNodeMenuState.fakeNode(nodePosition)
        }
    }
    
    @ViewBuilder @MainActor
    var sizeReadingNodeView: some View {
        fakeNodeView(boundsDisabled: false,
                     updateMenuActiveSelectionBounds: true)        
    }
    
    @MainActor
    var animatedNodeView: some View {
        fakeNodeView(boundsDisabled: true,
                     // animated-node view does not update active selection bounds
                     updateMenuActiveSelectionBounds: false)
        .frame(width: nodeWidth, height: nodeHeight)
        
        .scaleEffect(x: nodeScaleX, y: nodeScaleY)
        // NOTE: the node's .position comes AFTER the scaleEffect for the nodeScaleX etc.
        .position(nodePosition)
        
        //            .animation(Self.scaleAnimation, value: nodeScaleY)
        //            .animation(Self.scaleAnimation, value: nodeScaleX)
        
        .opacity(nodeOpacity)
        
        //            .animation(Self.opacityAnimation, value: nodeOpacity)
        
        // Apply GraphBaseView modifiers AFTER the node's frame, position, etc.
        // Applying same offset and scale as what nodes have, in same order.
        .offset(graphOffset.toCGSize)
        .scaleEffect(graphScale)
    }
}

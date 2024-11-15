//
//  InsertNodeMenuWrapper.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/19/24.
//

import Foundation
import SwiftUI

@Observable
final class InsertNodeMenuWrapperState: NSObject {
    
    // These values set in onAppear and when insertion animation completes
    var nodeOpacity: CGFloat = .zero

    var menuScaleX: CGFloat = .zero
    var menuScaleY: CGFloat = .zero

    var nodeScaleX: CGFloat = .zero
    var nodeScaleY: CGFloat = .zero

    var menuPosition: CGPoint = .zero
    var nodePosition: CGPoint = .zero

    // doesn't really matter, since overridden by actual node size
    var nodeWidth: CGFloat = 300.0
    var nodeHeight: CGFloat = 200.0
    
    var animatedNode: NodeViewModel?
    
    var menuHeight: CGFloat
    var screenSize: CGRect
    
    var menuCornerRadius: CGFloat = Self.shownMenuCornerRadius
}

extension InsertNodeMenuWrapperState {
    
    static let menuWidth: CGFloat = INSERT_NODE_MENU_WIDTH
    static let opacityAnimationDelay: Double = 0.25
    static let shownMenuScale: CGFloat = 1
        
    static let scaleAnimationDuration: Double = 0.4
    static let scaleAnimation = Animation.linear(duration: scaleAnimationDuration)
    
    // let opacity animation last a tiny bit longer
    static var opacityAnimationDuration: CGFloat {
        Self.scaleAnimationDuration - Self.opacityAnimationDelay/2
    }

    static var opacityAnimation: Animation {
        Animation
            .linear(duration: opacityAnimationDuration)
            .delay(Self.opacityAnimationDelay)
    }
    
    static let shownMenuCornerRadius: CGFloat = 16
    //    static let hiddenMenuCornerRadius: CGFloat = 98
    static let hiddenMenuCornerRadius: CGFloat = 60

}

extension InsertNodeMenuWrapperState {
    func getLargeNodeWidthScale(_ graphScale: CGFloat) -> CGFloat {
        Self.menuWidth / self.nodeWidth * (1 / graphScale)
    }
    
    func getLargeNodeHeightScale(_ graphScale: CGFloat) -> CGFloat {
        self.nodeHeight / self.menuHeight * graphScale
    }
    
    // Used by node-view only
    func getAdjustedMenuOrigin(_ graphOffset: CGPoint) -> CGPoint {
        // When the menu is shown and the node is hidden,
        // the node needs to be positioned directly underneath the menu;
        // since the node (but not the menu) is affected by graph offset,
        // we need to factor graph offset out of the menuOrigin the node will be using.
        var d = menuOrigin
        d.x -= graphOffset.x
        d.y -= graphOffset.y
        return d
    }
    
    var menuOrigin: CGPoint {
        CGPoint(x: screenWidth/2,
                y: screenHeight/2)
    }
    
    var screenWidth: CGFloat {
        // graphUI.frame.width
//        self.screenSize.width
        let k = self.screenSize.width
        log("screenWidth: \(k)")
        return k
    }

    var screenHeight: CGFloat {
        // graphUI.frame.height
        let k = self.screenSize.height
        log("screenHeight: \(k)")
        return k
    }

    // i.e. placing the menu in the center of the screen again;
    // done whenever view first appears, or we change menuOrigin (due to screen-resizing from on-screen keyboard)
    func prepareHiddenMenu(setHeightToMax: Bool = true) {
        // log("prepareHiddenMenu called: menuOrigin: \(menuOrigin)")

        self.menuCornerRadius = Self.shownMenuCornerRadius

        self.wrapperState.nodeOpacity = .zero
        self.wrapperState.menuScaleX = InsertNodeMenuWrapperState.shownMenuScale
        self.wrapperState.menuScaleY = InsertNodeMenuWrapperState.shownMenuScale

        self.wrapperState.nodeScaleX = self.wrapperState.getLargeNodeWidthScale(graphScale)
        self.wrapperState.nodeScaleY = self.wrapperState.getLargeNodeHeightScale(graphScale)

        // menu and animating-node start out in center of screen
        self.wrapperState.menuPosition = menuOrigin

        // Need to factor out graph offset, to get node placed under the menu
        self.wrapperState.nodePosition = self.getAdjustedMenuOrigin() // menuOrigin

//        if setHeightToMax {
//            self.menuHeight = INSERT_NODE_MENU_MAX_HEIGHT
//        }
    }
    
    
    @MainActor
    func animateNode(showMenu: Bool) {
        // factor out the graphScale,
        // since now the node needs to look like the menu
        let largeNodeWidthScale: CGFloat = self.getLargeNodeWidthScale()
        
        let largeNodeHeightScale: CGFloat = self.getLargeNodeHeightScale()

        withAnimation(InsertNodeMenuWrapperState.opacityAnimation) {
            wrapperState.nodeOpacity = showMenu ? 0 : 1
        }

        withAnimation(InsertNodeMenuWrapperState.scaleAnimation) {

            // Adjust the corner radius when menu hidden
            menuCornerRadius = showMenu ? InsertNodeMenuWrapperState.shownMenuCornerRadius : InsertNodeMenuWrapperState.hiddenMenuCornerRadius

            // Menu's opacity does not actually change during animation;
            // we merely let the node appear over it (z-index)

            self.nodeScaleX = showMenu ? largeNodeWidthScale : 1
            self.nodeScaleY = showMenu ? largeNodeHeightScale : 1

            // Node's self.hidden position = menu position + graph offset factored OUT
            self.nodePosition = showMenu ? getAdjustedMenuOrigin() : getNodeDestination()
        }
    }
    
    @MainActor
    func animateMenu(showMenu: Bool,
                     document: StitchDocumentViewModel,
                     sidebarFullWidth: CGFloat,
                     graphScale: CGFloat,
                     graphUI: GraphUIState,
                     graphMovement: GraphMovementObserver) {
        let graphOffset: CGSize = graphMovement.localPosition.toCGSize
        let graphScale: CGFloat = graphMovement.zoomData.zoom
        let nodeDestination = self.getNodeDestination(
            document: document,
            sidebarFullWidth: sidebarFullWidth,
            graphScale: graphScale)
        
        // factor in the graphScale,
        // since now the menu needs to look like the node
        let smallMenuWidthScale: CGFloat = self.nodeWidth / Self.menuWidth * graphScale
        
        //        nodeHeight/Self.menuHeight * graphScale
        let smallMenuHeightScale: CGFloat = self.nodeHeight / self.menuHeight * graphScale

        withAnimation(Self.scaleAnimation) {
            self.menuScaleX = showMenu ? Self.shownMenuScale : smallMenuWidthScale
            self.menuScaleY = showMenu ? Self.shownMenuScale : smallMenuHeightScale

            // node destination's diff from center
            let diffX = screenWidth/2 - nodeDestination.x

            //            let diffY = screenHeight/2 - nodeDestination.height

            // Use non-changing height of screen for menu's animation-end position;
            // i.e. animate the menu to a position as if the keyboard were not on screen.
            let diffY = graphUI.graphFrame.size.height/2 - nodeDestination.y

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

            self.menuPosition = showMenu
                ? menuOrigin
                : menuHiddenPosition
        } // withAnimation

    }
    
    @MainActor
    func getNodeDestination(document: StitchDocumentViewModel,
                            sidebarFullWidth: CGFloat,
                            graphScale: CGFloat) -> CGPoint {
        
        let adjustedDoubleTapLocation = document.adjustedDoubleTapLocation(document.visibleGraph.localPosition)
        
        var defaultCenter = document.graphUI.center(
            document.visibleGraph.localPosition,
            graphScale: graphScale)
        
        // From ChatGPT -- this works!
        let sidebarAdjustment = sidebarFullWidth * ((1 + graphScale) / (2 * graphScale))
        
        //        let sidebarAdjustment = 0.0
        log("getNodeDestination: sidebarAdjustment: \(sidebarAdjustment)")
        
        if document.llmRecording.isRecording {
            return defaultCenter
        } else if var adjustedDoubleTapLocation = adjustedDoubleTapLocation {
            adjustedDoubleTapLocation.x += sidebarAdjustment
            return adjustedDoubleTapLocation
        } else {
            log("getNodeDestination: defaultCenter was: \(defaultCenter)")
            defaultCenter.x += sidebarAdjustment
            log("getNodeDestination: defaultCenter is now: \(defaultCenter)")
            return defaultCenter
        }
    }
    
    
    
}

struct InsertNodeMenuWrapper: View {
    let wrapperState: InsertNodeMenuWrapperState
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graphUI: GraphUIState
    
//    @Binding var menuHeight: CGFloat
//    @Binding var screenSize: CGSize
    var menuHeight: CGFloat
    var deviceScreen: CGRect
        
    var graphScale: CGFloat {
        graphMovement.zoomData.zoom
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

//    @State var menuCornerRadius: CGFloat = Self.shownMenuCornerRadius

    // We show the modal background when menu is toggled but node-animation has not yet started
    var showModalBackground: Bool {
        graphUI.insertNodeMenuState.show
            && !graphUI.insertNodeMenuState.menuAnimatingToNode
    }

    var menuAnimatingToNode: Bool {
        graphUI.insertNodeMenuState.menuAnimatingToNode
    }
        
    var graphOffset: CGPoint {
        graphMovement.localPosition
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
            NodeTypeView(document: document,
                         graph: document.visibleGraph,
                         node: node,
                         canvasNode: canvas,
                         atleastOneCommentBoxSelected: false,
                         activeIndex: .init(1),
                         groupNodeFocused: nil,
                         adjustmentBarSessionId: .fakeId,
                         boundsReaderDisabled: boundsDisabled,
                         // fake node does NOT use position handler
                         usePositionHandler: false,
                         updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds)
            // TODO: why is this necessary
            
            .id(node.id)
            .onChange(of: insertNodeMenuState.activeSelectionBounds) { oldValue, newValue in
                
                //                log("InsertNodeMenuWrapper: onChange of insertNodeMenuState.activeSelectionBounds:  insertNodeMenuState.activeSelection?.data.displayTitle: \(insertNodeMenuState.activeSelection?.data.displayTitle)")
                //                log("InsertNodeMenuWrapper: onChange of insertNodeMenuState.activeSelectionBounds: oldValue: \(oldValue)")
                //                log("InsertNodeMenuWrapper: onChange of insertNodeMenuState.activeSelectionBounds: newValue: \(newValue)")
                
                // update the node size to use these bounds
                if let rect: CGRect = newValue {
                    //                    log("updating nodeWidth and nodeHeight")
                    //                    log("rect.size.width: \(rect.size.width)")
                    //                    log("rect.size.height: \(rect.size.height)")
                    nodeWidth = rect.size.width
                    nodeHeight = rect.size.height
                    
                    // we should also reset node scale etc.?
                    //                        prepareHiddenMenu()
                    prepareHiddenMenu(setHeightToMax: false)
                    
                    // Once we have read the size of the active selection, we
                    // TODO: grab the `activeSelection` from the InsertNodeMenuState instead?
                    dispatch(ActiveSelectionSizeReadingCompleted(activeSelection: node.asActiveSelection))
                }
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
            animatingNodeOpacity: self.wrapperState.nodeOpacity)
        
        // scale first, THEN position
        .scaleEffect(x: wrapperState.menuScaleX,
                     y: wrapperState.menuScaleY)
        
        // use .position modifier to match node's use of .position modifier
        .position(wrapperState.menuPosition)
        
        //            .offset(x: -sidebarHalfWidth)
    }
    
    var sidebarFullWidth: CGFloat {
        graphUI.sidebarWidth
    }
    
    var sidebarHalfWidth: CGFloat {
        graphUI.sidebarWidth/2
    }
    
    var body: some View {
        ZStack {
            MODAL_BACKGROUND_COLOR
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(showModalBackground ? 1 : 0)
                .onTapGesture {
                    dispatch(CloseAndResetInsertNodeMenu())
                }
            // IMPORTANT: keep `nodeSizeReadingView` in an .overlay, so that the changing of the node during insert-node-menu query-typing does not
                .overlay {
                    // NodeView used only for reading the size of the insert node menu's active selection;
                    // its size does not change becasue it is not animated.
                    
                    // Only use node-size-reading view when not actively animating
                    if !graphUI.insertNodeMenuState.hiddenNodeId.isDefined {
                        sizeReadingNodeView.opacity(0)
                    }
                }
            
            // Insert Node Menu view
            if graphUI.insertNodeMenuState.show {
                menuView
            }
                        
            // NodeView used only for animation; does not read size,
            // since its size changes during animation.
            // Note: don't render this NodeView until we have committed our choice.
            if graphUI.insertNodeMenuState.hiddenNodeId.isDefined {
                animatedNodeView
                    .opacity(graphUI.insertNodeMenuState.show ? 1 : 0)
                    .onChange(of: graphUI.insertNodeMenuState.show) {
                        // Surfacing the menu may cause the responder chain to break, causing key modifiers
                        // to lose tracking for end state
                        dispatch(KeyModifierReset())
                    }
//                    .offset(x: -sidebarHalfWidth)
            }
        }
        .onAppear {
            //            log("onAppear")

            // default, but also updated when GeometryReader changes
            //            self.screenHeight = graphUI.frame.height
            wrapperState.prepareHiddenMenu()
        }
        .onChange(of: self.wrapperState.menuOrigin, initial: true) { _, _ in
            //            log("ContentView: onChange of menuOrigin: oldValue: \(oldValue)")
            //            log("ContentView: onChange of menuOrigin: newValue: \(newValue)")
            // don't change during animation
            if !graphUI.insertNodeMenuState.menuAnimatingToNode {
                wrapperState.prepareHiddenMenu(setHeightToMax: false)
            }
        }
        .onChange(of: self.wrapperState.screenSize, initial: true) { _, _ in
            //            log("ContentView: onChange of self.screenSize: oldValue: \(oldValue)")
            //            log("ContentView: onChange of self.screenSize: newValue: \(newValue)")
            if !graphUI.insertNodeMenuState.menuAnimatingToNode {
                wrapperState.prepareHiddenMenu(setHeightToMax: false)
            }
        }
        .onChange(of: graphUI.insertNodeMenuState.menuAnimatingToNode, initial: true) { _, newValue in
            // log("ContentView: onChange of menuAnimatingToNode: oldValue: \(oldValue)")
            // log("ContentView: onChange of menuAnimatingToNode: newValue: \(newValue)")

            // Only fire these when animating = true and the menu toggle status = open
            if newValue && graphUI.insertNodeMenuState.show {
                wrapperState.animateMenu(showMenu: graphUI.insertNodeMenuState.show,
                                         document: document,
                                         sidebarFullWidth: graphUI.sidebarWidth,
                                         graphScale: graphScale,
                                         graphUI: graphUI,
                                         graphMovement: graphMovement)
                
                wrapperState.animateNode(showMenu: graphUI.insertNodeMenuState.show)
            }
            // When animation completes, reset menu state
            if !newValue {
                wrapperState.prepareHiddenMenu()
            }
        }
        // Keeping the local state `animatedNode` up to date with our activeSelection.
        .onChange(of: graphUI.insertNodeMenuState.activeSelection, initial: true) { _, _ in
            //            log("ContentView: onChange of activeSelection: oldValue: \(oldValue)")
            //            log("ContentView: onChange of activeSelection: newValue: \(newValue)")
            wrapperState.animatedNode = graphUI.insertNodeMenuState.fakeNode(wrapperState.nodePosition)
        }
    }
    
    @ViewBuilder @MainActor
    var sizeReadingNodeView: some View {
        if graphUI.insertNodeMenuState.readActiveSelectionSize {
            fakeNodeView(boundsDisabled: false,
                         updateMenuActiveSelectionBounds: true)
        } else {
            EmptyView()
        }
    }
    
    @MainActor
    var animatedNodeView: some View {
        fakeNodeView(boundsDisabled: true,
                     // animated-node view does not update active selection bounds
                     updateMenuActiveSelectionBounds: false)
        
        .frame(width: wrapperState.nodeWidth,
               height: wrapperState.nodeHeight)
        
        .scaleEffect(x: wrapperState.nodeScaleX,
                     y: wrapperState.nodeScaleY)
        // NOTE: the node's .position comes AFTER the scaleEffect for the nodeScaleX etc.
        .position(wrapperState.nodePosition)
        
        //            .animation(Self.scaleAnimation, value: nodeScaleY)
        //            .animation(Self.scaleAnimation, value: nodeScaleX)
        
        .opacity(wrapperState.nodeOpacity)
        
        //            .animation(Self.opacityAnimation, value: nodeOpacity)
        
        // Apply GraphBaseView modifiers AFTER the node's frame, position, etc.
        // Applying same offset and scale as what nodes have, in same order.
        .offset(graphOffset.toCGSize)
        .scaleEffect(graphScale)
    }
}

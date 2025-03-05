//
//  StitchUIScrollView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/12/24.
//

import SwiftUI
import Foundation
    
//let WHOLE_GRAPH_LENGTH: CGFloat = 30000 // 30,000 x 30,000
let WHOLE_GRAPH_LENGTH: CGFloat = 300000 // 300,000 x 300,000

let WHOLE_GRAPH_SIZE = CGSize(width: WHOLE_GRAPH_LENGTH,
                              height: WHOLE_GRAPH_LENGTH)

let WHOLE_GRAPH_COORDINATE_SPACE = "WHOLE_GRAPH_COORDINATE_SPACE"

let ABSOLUTE_GRAPH_CENTER = CGPoint(x: WHOLE_GRAPH_LENGTH/2,
                                    y: WHOLE_GRAPH_LENGTH/2)

struct StitchUIScrollViewModifier: ViewModifier {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    
    @MainActor
    var selectionState: GraphUISelectionState {
        graph.selection
    }
    
    func body(content: Content) -> some View {
        StitchUIScrollView(document: document,
                           graph: graph) {
            ZStack {
                content
                    .ignoresSafeArea()
                
                APP_BACKGROUND_COLOR
                    .zIndex(-99999)
                    .frame(WHOLE_GRAPH_SIZE)
                    .coordinateSpace(name: WHOLE_GRAPH_COORDINATE_SPACE)
                    .ignoresSafeArea()
                    .gesture(SpatialTapGesture(count: 2,
                                               coordinateSpace: .local)
                        .onEnded({ value in
                            dispatch(GraphDoubleTappedAction(location: value.location))
                        })
                    )
                    .simultaneousGesture(TapGesture(count: 1)
                        .onEnded({
                            graph.graphTapped(document: document)
                        })
                    )
                
                    .gesture(StitchLongPressGestureRecognizerRepresentable())
                    .gesture(StitchTrackpadGraphBackgroundPanGesture())
                
                // RENDERING THE NODE CURSOR SELECTION BOX HERE
                
                // Selection box and cursor
                if let expansionBox = selectionState.expansionBox {
                    ExpansionBoxView(graph: graph,
                                     document: document,
                                     box: expansionBox)
                }
                
                if selectionState.isSelecting,
                   let currentDrag = selectionState.dragCurrentLocation {
                    CursorDotView(
                        currentDragLocation: currentDrag,
                        isFingerOnScreenSelection: selectionState.isFingerOnScreenSelection,
                        scale: document.graphMovement.zoomData)
                }
            } // ZStack
        } // StitchUIScrollView
        
        .background {
#if DEV_DEBUG
            Color.red
#else
            APP_BACKGROUND_COLOR
#endif
            
        }
        .ignoresSafeArea()
    }
}


struct StitchUIScrollView<Content: View>: UIViewRepresentable {
    let document: StitchDocumentViewModel
    let graph: GraphState
    @ViewBuilder var content: () -> Content
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        
        #if !DEV_DEBUG
        // Hides scroll indicators
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        #endif
        
        // Enable zooming
        scrollView.minimumZoomScale = MIN_GRAPH_SCALE // 0.1
        scrollView.maximumZoomScale = MAX_GRAPH_SCALE // 5.0
        scrollView.delegate = context.coordinator
        
        // CATALYST AND IPAD-WITH-TRACKPAD: IMMEDIATELY START THE NODE CURSOR SELECTION BOX
        let trackpadPanGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handlePan))
        // Only listen to click and drag from mouse
        trackpadPanGesture.allowedScrollTypesMask = [.discrete]
        // ignore screen; uses trackpad
        trackpadPanGesture.allowedTouchTypes = [TRACKPAD_TOUCH_ID]
        // 1 touch ensures a click and drag event
        trackpadPanGesture.minimumNumberOfTouches = 1
        trackpadPanGesture.maximumNumberOfTouches = 1
        scrollView.addGestureRecognizer(trackpadPanGesture)
        
        // Add SwiftUI content inside the scroll view
        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostedView)
        
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])
        
        scrollView.contentSize = WHOLE_GRAPH_SIZE
        
        self.initializeContentOffset(scrollView)
                
        return scrollView
    }
    
    private func initializeContentOffset(_ scrollView: UIScrollView) {

        // TODO: either continue to start graph at center, or persist BOTH zoom and offset (persisting offset but not zoom makes it easy to reopen the graph with no nodes visible, especially if we had been highly zoomed out)
        // let newOffset =  self.document.localPosition
        log("StitchUIScrollView: USING GRAPH'S ABSOLUTE CENTER, NOT PERSISTED LOCAL POSITION")
        let newOffset =  CGPoint(x: WHOLE_GRAPH_LENGTH/2,
                                 y: WHOLE_GRAPH_LENGTH/2)
        
        scrollView.setContentOffset(newOffset, animated: false)
        
        dispatch(GraphScrollDataUpdated(
            newOffset: newOffset,
            newZoom: scrollView.zoomScale
        ))
    }
        
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Update content when SwiftUI view changes
        context.coordinator.hostingController.rootView = content()
        
        if let canvasJumpLocation = graph.canvasJumpLocation {
            uiView.setContentOffset(canvasJumpLocation, animated: true)
            dispatch(GraphScrollDataUpdated(
                newOffset: uiView.contentOffset,
                newZoom: uiView.zoomScale
            ))
            graph.canvasJumpLocation = nil
            
            context.coordinator.borderCheckingDisabled = true
            
            // During the animation to the jump-location,
            // we do not want to check the borders
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                context.coordinator.borderCheckingDisabled = false
            }
        } // if let
                
        if let zoomInAmount = graph.canvasZoomedIn.zoomAmount {
            // log("StitchUIScrollView: ZOOM IN: uiView.zoomScale was: \(uiView.zoomScale)")
            // log("StitchUIScrollView: ZOOM IN: uiView.contentOffset was: \(uiView.contentOffset)")
            
            // TODO: 'appropriate feeling' zoom step size is probably some non-linear curve, since zoom step size of 0.1 near max zoom-in level also feels bad (too small)
            if uiView.zoomScale < 0.3,
               graph.canvasZoomedIn == .shortcutKey {
                uiView.zoomScale += zoomInAmount/4 //zoomInAmount/2
            } else if uiView.zoomScale < 0.4  {
                uiView.zoomScale += zoomInAmount/2
            } else {
                uiView.zoomScale += zoomInAmount
            }
            
            // Does zooming in automatically modify the contentOffset ?
            // log("StitchUIScrollView: ZOOM IN: uiView.zoomScale is now: \(uiView.zoomScale)")
            // log("StitchUIScrollView: ZOOM IN: uiView.contentOffset is now: \(uiView.contentOffset)")
            
            dispatch(GraphScrollDataUpdated(
                newOffset: uiView.contentOffset,
                newZoom: uiView.zoomScale
            ))
            
            graph.canvasZoomedIn = .noZoom
            context.coordinator.borderCheckingDisabled = true
            
            // Do not check borders during zoom.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                context.coordinator.borderCheckingDisabled = false
            }
        }
        
        if let zoomOutAmount = graph.canvasZoomedOut.zoomAmount {
            
            // log("StitchUIScrollView: ZOOM OUT: uiView.zoomScale was: \(uiView.zoomScale)")
            // log("StitchUIScrollView: ZOOM OUT: uiView.contentOffset was: \(uiView.contentOffset)")
            if uiView.zoomScale < 0.3,
               graph.canvasZoomedOut == .shortcutKey {
                uiView.zoomScale -= zoomOutAmount/4
            } else if uiView.zoomScale < 0.4  {
                uiView.zoomScale -= zoomOutAmount/2
            } else {
                uiView.zoomScale -= zoomOutAmount
            }
            
            // log("StitchUIScrollView: ZOOM OUT: uiView.zoomScale is now: \(uiView.zoomScale)")
            // log("StitchUIScrollView: ZOOM OUT: uiView.contentOffset is now: \(uiView.contentOffset)")
            
            dispatch(GraphScrollDataUpdated(
                newOffset: uiView.contentOffset,
                newZoom: uiView.zoomScale
            ))
            
            graph.canvasZoomedOut = .noZoom
            context.coordinator.borderCheckingDisabled = true
            
            // Do not check borders during zoom.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                context.coordinator.borderCheckingDisabled = false
            }
        }
        
        if let canvasPageOffsetChanged = graph.canvasPageOffsetChanged,
           let canvasPageZoomScaleChanged = graph.canvasPageZoomScaleChanged {
            // log("StitchUIScrollView: canvasPageOffsetChanged: \(canvasPageOffsetChanged)")
            // log("StitchUIScrollView: canvasPageZoomScaleChanged: \(canvasPageZoomScaleChanged)")
                        
            /*
             VERY IMPORTANT: when manually setting UIScrollView's zoomScale and contentOffset at the same time,
             WE MUST UPDATE zoomScale FIRST.
             Otherwise `.setContentOffset` uses the OLD zoomScale and auto-adjusts the manual contentOffset we want to provide.
             */
            uiView.zoomScale = canvasPageZoomScaleChanged
            uiView.setContentOffset(canvasPageOffsetChanged, animated: false)
 
            dispatch(GraphScrollDataUpdated(
                newOffset: uiView.contentOffset,
                newZoom: uiView.zoomScale
            ))
            
            context.coordinator.borderCheckingDisabled = true
            
            graph.canvasPageOffsetChanged = nil
            graph.canvasPageZoomScaleChanged = nil
            
            // Do not check borders during zoom.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                context.coordinator.borderCheckingDisabled = false
            }
            
        }
    }
    
    func makeCoordinator() -> StitchScrollCoordinator<Content> {
        StitchScrollCoordinator(content: content(),
                                document: document)
    }
    
}

// All available delegate methods described here: https://developer.apple.com/documentation/uikit/uiscrollviewdelegate
final class StitchScrollCoordinator<Content: View>: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let hostingController: UIHostingController<Content>
    
    // Used during spacebar + trackpad click-&-drag gesture
    private var initialContentOffset: CGPoint = .zero
    
    // Broadly speaking: do not check borders when jumping to a canvas item, or zooming
    var borderCheckingDisabled: Bool = false
    
    weak var document: StitchDocumentViewModel?
    
    init(content: Content,
         document: StitchDocumentViewModel) {
        self.hostingController = UIHostingController(rootView: content)
        self.hostingController.view.backgroundColor = .clear
        self.document = document
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // log("StitchUIScrollView: gestureRecognizer: shouldRecognizeSimultaneouslyWith")
        return true
    }

    
    static func updateGraphScrollData(_ scrollView: UIScrollView) {
        dispatch(GraphScrollDataUpdated(
            newOffset: scrollView.contentOffset,
            newZoom: scrollView.zoomScale))
    }
    
    // MANAGING ZOOMING
    
    // UIScrollViewDelegate method for zooming
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return hostingController.view
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView,
                                    with view: UIView?) {
        // log("scrollViewWillBeginZooming")
        self.borderCheckingDisabled = true
        self.checkBorder(scrollView)
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView,
                                 with view: UIView?,
                                 atScale scale: CGFloat) {
        // log("scrollViewDidEndZooming")
        self.borderCheckingDisabled = false
        self.checkBorder(scrollView)
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // log("scrollViewDidZoom")
        self.borderCheckingDisabled = true // Disable border-checking during an active zoom
         self.checkBorder(scrollView)
    }
    
    // RESPONDING TO SCROLLING AND DRAGGING
    
    // Note: called even by ZOOMING
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // log("scrollViewDidScroll")
        self.checkBorder(scrollView)
    }
    
    // Only called when scroll first begins, not DURING scroll;
    // Also apparently never triggered by zooming
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // log("scrollViewWillBeginDragging")
        self.borderCheckingDisabled = false
        self.checkBorder(scrollView)
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // log("scrollViewWillEndDragging")
        self.borderCheckingDisabled = false
        self.checkBorder(scrollView)
    }
    
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        // log("scrollViewWillBeginDecelerating")
        self.borderCheckingDisabled = false
        self.checkBorder(scrollView)
    }
    
    // Called when scroll-view movement comes to an end
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // log("scrollViewDidEndDecelerating")
        self.borderCheckingDisabled = false
        self.checkBorder(scrollView)
    }
        
    // RESPONDING TO SCROLL ANIMATIONS
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        // log("scrollViewDidEndScrollingAnimation")
        self.checkBorder(scrollView)
    }
    
    // CHECKING THE BORDER
    
    func checkBorder(_ scrollView: UIScrollView) {
                        
        guard let document = self.document else {
            // log("checkBorder: no document, exiting early")
            return
        }
        let graph = document.graph
        let cache = graph.visibleNodesViewModel.infiniteCanvasCache

        // Do not check borders for ~1 second after (1) jumping to an item on the canvas or (2) zooming in/out
        
        guard !self.borderCheckingDisabled else {
            // log("checkBorder: border checking disabled")
            Self.updateGraphScrollData(scrollView)
            return
        }
        
        // Only check borders if we have cached size and position data for canvas items
        let canvasItemsInFrame = graph
            .getCanvasItemsAtTraversalLevel(groupNodeFocused: document.groupNodeFocused?.groupNodeId).filter({ $0.isVisibleInFrame(graph.visibleCanvasIds) })
        
        guard let westNode = graph.westernMostNodeForBorderCheck(canvasItemsInFrame,
                                                                 groupNodeFocused: document.groupNodeFocused?.groupNodeId),
              let eastNode = graph.easternMostNodeForBorderCheck(canvasItemsInFrame,
                                                                 groupNodeFocused: document.groupNodeFocused?.groupNodeId),
              let westBounds = cache.get(westNode.id),
              let eastBounds = cache.get(eastNode.id),
              let northNode = graph.northernMostNodeForBorderCheck(canvasItemsInFrame,
                                                                   groupNodeFocused: document.groupNodeFocused?.groupNodeId),
              let southNode = graph.southernMostNodeForBorderCheck(canvasItemsInFrame,
                                                                   groupNodeFocused: document.groupNodeFocused?.groupNodeId),
              let northBounds = cache.get(northNode.id),
              let southBounds = cache.get(southNode.id) else {
            
            // log("StitchUIScrollView: scrollViewDidScroll: MISSING WEST, EAST, SOUTH OR NORTH IN-FRAME NODES OR BOUNDS")
            Self.updateGraphScrollData(scrollView)
            return
        }
        
        let scale = scrollView.zoomScale
        
        let screenWidth = document.graphUI.frame.width
        let screenHeight = document.graphUI.frame.height
        
        let westernMostNodeCachedBoundsOriginX: CGFloat = westBounds.origin.x
        let easternMostNodeCachedBoundsOriginX: CGFloat = eastBounds.origin.x
        let northernMostNodeCachedBoundsOriginY: CGFloat = northBounds.origin.y
        let southernMostNodeCachedBoundsOriginY: CGFloat = southBounds.origin.y
        
        // log("StitchUIScrollView: scrollViewDidScroll: westNode.id: \(westNode.id)")
        // log("StitchUIScrollView: scrollViewDidScroll: eastNode.id: \(eastNode.id)")
        // log("StitchUIScrollView: scrollViewDidScroll: northNode.id: \(northNode.id)")
        // log("StitchUIScrollView: scrollViewDidScroll: southNode.id: \(southNode.id)")
        
        // log("StitchUIScrollView: scrollViewDidScroll: westernMostNodeCachedBoundsOriginX: \(westernMostNodeCachedBoundsOriginX)")
        // log("StitchUIScrollView: scrollViewDidScroll: easternMostNodeCachedBoundsOriginX: \(easternMostNodeCachedBoundsOriginX)")
        // log("StitchUIScrollView: scrollViewDidScroll: northernMostNodeCachedBoundsOriginY: \(northernMostNodeCachedBoundsOriginY)")
        // log("StitchUIScrollView: scrollViewDidScroll: southernMostNodeCachedBoundsOriginY: \(southernMostNodeCachedBoundsOriginY)")
        
        // Minimum contentOffset can never be less than 0
        let scaledNodeWidth = (southBounds.width/4 * scale)
        let minimumContentOffsetX = (westernMostNodeCachedBoundsOriginX * scale) - screenWidth + scaledNodeWidth
        let maximumContentOffsetX = (easternMostNodeCachedBoundsOriginX * scale) - scaledNodeWidth
        
        // log("StitchUIScrollView: scrollViewDidScroll: minimumContentOffsetX: \(minimumContentOffsetX)")
        // log("StitchUIScrollView: scrollViewDidScroll: maximumContentOffsetX: \(maximumContentOffsetX)")
        
        let scaledNodeHeight = (southBounds.height/4 * scale)
        let minimumContentOffsetY = (northernMostNodeCachedBoundsOriginY * scale) - screenHeight + scaledNodeHeight
        let maximumContentOffsetY = (southernMostNodeCachedBoundsOriginY * scale) - scaledNodeHeight
        
        // log("StitchUIScrollView: scrollViewDidScroll: scaledNodeHeight: \(scaledNodeHeight)")
        // log("StitchUIScrollView: scrollViewDidScroll: minimumContentOffsetY: \(minimumContentOffsetY)")
        // log("StitchUIScrollView: scrollViewDidScroll: maximumContentOffsetY: \(maximumContentOffsetY)")
        
        let westernMostNodeAtEasternScreenEdge = scrollView.contentOffset.x <= minimumContentOffsetX
        let easternMostNodeAtWesternScreenEdge = scrollView.contentOffset.x >= maximumContentOffsetX
        
        // log("StitchUIScrollView: scrollViewDidScroll: westernMostNodeAtEasternScreenEdge: \(westernMostNodeAtEasternScreenEdge)")
        // log("StitchUIScrollView: scrollViewDidScroll: easternMostNodeAtWesternScreenEdge: \(easternMostNodeAtWesternScreenEdge)")
        
        let northernMostNodeAtSouthernScreenEdge = scrollView.contentOffset.y <= minimumContentOffsetY
        let southernMostNodeAtNorthernScreenEdge = scrollView.contentOffset.y >= maximumContentOffsetY
        
        // log("StitchUIScrollView: scrollViewDidScroll: northernMostNodeAtSouthernScreenEdge: \(northernMostNodeAtSouthernScreenEdge)")
        // log("StitchUIScrollView: scrollViewDidScroll: southernMostNodeAtNorthernScreenEdge: \(southernMostNodeAtNorthernScreenEdge)")
        
        var hitBorder = false
        
        var finalContentOffsetX = scrollView.contentOffset.x
        var finalContentOffsetY = scrollView.contentOffset.y
        
        if westernMostNodeAtEasternScreenEdge {
            log("StitchUIScrollView: scrollViewDidScroll: hit min x offset")
            finalContentOffsetX = minimumContentOffsetX
            hitBorder = true
        }
        
        if easternMostNodeAtWesternScreenEdge {
            log("StitchUIScrollView: scrollViewDidScroll: hit max x offset")
            finalContentOffsetX = maximumContentOffsetX
            hitBorder = true
        }
        
        if northernMostNodeAtSouthernScreenEdge {
            log("StitchUIScrollView: scrollViewDidScroll: hit min y offset")
            finalContentOffsetY = minimumContentOffsetY
            hitBorder = true
        }
        
        if southernMostNodeAtNorthernScreenEdge {
            log("StitchUIScrollView: scrollViewDidScroll: hit max y offset")
            finalContentOffsetY = maximumContentOffsetY
            hitBorder = true
        }
        
        // `setContentOffset` interrupts UIScrollView's momentum, so we only do it if we actually hit a border
        if hitBorder {
            log("StitchUIScrollView: scrollViewDidScroll: hit border")
            let finalOffset = CGPoint(x: finalContentOffsetX, y: finalContentOffsetY)
            // log("StitchUIScrollView: scrollViewDidScroll: hit border: finalContentOffsetX: \(finalContentOffsetX)")
            // log("StitchUIScrollView: scrollViewDidScroll: hit border: finalContentOffsetY: \(finalContentOffsetY)")
            scrollView.setContentOffset(finalOffset, animated: false)
            dispatch(GraphScrollDataUpdated(
                newOffset: finalOffset,
                newZoom: scrollView.zoomScale
            ))
        } else {
            log("StitchUIScrollView: scrollViewDidScroll: did not hit border")
            // log("StitchUIScrollView: scrollViewDidScroll: did not hit border: scrollView.contentOffset.x: \(scrollView.contentOffset.x)")
            // log("StitchUIScrollView: scrollViewDidScroll: did not hit border: scrollView.contentOffset.y: \(scrollView.contentOffset.y)")
            Self.updateGraphScrollData(scrollView)
        }
    }
    
    // Handle pan gesture with boundary checks
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let document = document else {
            log("StitchUIScrollView: handlePan: no document")
            return
        }
        
        let isSpaceHeld = document.keypressState.isSpacePressed
        let isCmdHeld = document.keypressState.isCommandPressed
        let isScrollWheel = gesture.numberOfTouches == 0
        let isValidScroll = isSpaceHeld || isScrollWheel
        
        guard isValidScroll else {
            return
        }
        
        guard let scrollView = gesture.view as? UIScrollView else {
            return
        }
        
        let translation = gesture.translation(in: scrollView)
        
        // Handle CMD + scroll
        guard !isCmdHeld else {
            self.graphZoom(gesture,
                           translation: translation)
            return
        }
        
        self.graphScroll(gesture,
                         translation: translation,
                         scrollView: scrollView)
    }
    
    // TODO: CMD + zoom needs improved support with zooming on a cursor along with zoom rate.
    func graphZoom(_ gesture: UIPanGestureRecognizer,
                   translation: CGPoint) {
        // Determine zoom direction based on the y-direction of the translation
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                // Scrolling up, zoom in
                self.document?.visibleGraph.graphZoomedIn(.mouseWheel)
            } else if translation.y < 0 {
                // Scrolling down, zoom out
                self.document?.visibleGraph.graphZoomedOut(.mouseWheel)
            }
        default:
            break
        }
    }
    
    func graphScroll(_ gesture: UIPanGestureRecognizer,
                     translation: CGPoint,
                     scrollView: UIScrollView) {
        
        guard let document = self.document else {
            log("graphScroll: no document")
            return
        }
        
        switch gesture.state {
        case .began:
            initialContentOffset = scrollView.contentOffset
            document.graphUI.activeSpacebarClickDrag = true
            
        case .changed:
            document.graphUI.activeSpacebarClickDrag = true
            
            let screenHeight = document.graphUI.frame.height
            let screenWidth = document.graphUI.frame.width
            
            // UIScrollView's contentOffset can never be negative
            let minOffset: CGFloat = 0
            
            // Note: `scrollView.contentSize.width` is already `WHOLE_GRAPH_LENGTH * scale`
            // e.g. if graph length = 30k, and scale = 0.1, scrollViewContentSize length is 3k
            let maxOffsetX = scrollView.contentSize.width - screenWidth
            let maxOffsetY = scrollView.contentSize.height - screenHeight
            
            // something about this not quite right vs simpler PureZoom
            var newX = initialContentOffset.x - translation.x
            var newY = initialContentOffset.y - translation.y
            
            if newX < minOffset {
                newX = minOffset
            }
            
            if newY < minOffset {
                newY = minOffset
            }
            
            if newX > maxOffsetX {
                newX = maxOffsetX
            }
            
            if newY > maxOffsetY {
                newY = maxOffsetY
            }
            
            // these are the proper limits but really,
            let newOffset = CGPoint(x: newX, y: newY)
            
            scrollView.setContentOffset(newOffset, animated: false)
            
            dispatch(GraphScrollDataUpdated(
                newOffset: newOffset,
                newZoom: scrollView.zoomScale
            ))
            
        case .possible:
            log("StitchUIScrollView: handlePan: possible")
            
        case .ended, .cancelled, .failed:
            log("StitchUIScrollView: handlePan: ended, canceled or failed")
            document.graphUI.activeSpacebarClickDrag = false
            scrollView.setContentOffset(scrollView.contentOffset,
                                        animated: false)
            Self.updateGraphScrollData(scrollView)
            
        @unknown default:
            log("StitchUIScrollView: handlePan: default")
        }
    }
}

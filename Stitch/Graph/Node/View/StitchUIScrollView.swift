//
//  StitchUIScrollView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/12/24.
//

import SwiftUI

//let WHOLE_GRAPH_LENGTH: CGFloat = 300000

let WHOLE_GRAPH_LENGTH: CGFloat = 30000

let WHOLE_GRAPH_SIZE: CGSize = .init(
    width: WHOLE_GRAPH_LENGTH,
    height: WHOLE_GRAPH_LENGTH)

//let WHOLE_GRAPH_LENGTH: CGFloat = 3000

let WHOLE_GRAPH_COORDINATE_SPACE = "WHOLE_GRAPH_COORDINATE_SPACE"

struct StitchUIScrollViewModifier: ViewModifier {
    let document: StitchDocumentViewModel
    
    @MainActor
    var selectionState: GraphUISelectionState {
        document.graphUI.selection
    }
    
    func body(content: Content) -> some View {
        StitchUIScrollView(contentSize: WHOLE_GRAPH_SIZE,
                           document: document) {
            ZStack {
                content
                // places existing nodes in center like you expected before applying the UIScrollView
                // TODO: DEC 12: how to place existing nodes such that we imitate the old .offset of graph.localPosition ?
                //                    .offset(x: WHOLE_GRAPH_LENGTH/2,
                //                            y: WHOLE_GRAPH_LENGTH/2)
                    .ignoresSafeArea()
                
                
                // With `GraphGestureBackgroundView`, we can't even double tap etc. anymore?
                //                GraphGestureBackgroundView(document: document) {
                
                Color.blue.opacity(0.9)
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
                            dispatch(GraphTappedAction())
                        }))
                
                //                        .modifier(iPadFingerRecognzerViewModifer())
                //                }
                //                .zIndex(-99999)
                
                    .gesture(StitchLongPressGestureRecognizerRepresentable())
                
                // THIS IS BETTER: HANDLES BOTH ZOOMING AND SCROLLING PROPERLY
                
                    .gesture(StitchTrackpadGraphBackgroundPanGesture())
                
                
                // RENDERING THE NODE CURSOR SELECTION BOX HERE
                
                // Selection box and cursor
                if let expansionBox = selectionState.expansionBox {
                    ExpansionBoxView(graph: document.graph,
                                     box: expansionBox,
                                     scale: document.graphMovement.zoomData.final)
//                    ExpansionBoxView(box: expansionBox,
//                                     )
                }
                
                if selectionState.isSelecting,
                   let currentDrag = selectionState.dragCurrentLocation {
                    CursorDotView(
                        currentDragLocation: currentDrag,
                        isFingerOnScreenSelection: selectionState.isFingerOnScreenSelection,
                        scale: document.graphMovement.zoomData.final)
                }
            }
        }
        
        // what happens if we get node
        // BAD:
        // .gesture(StitchTrackpadPanGestureRecognizerRepresentable())
        
        // VERY BAD
        //        .frame(width: WHOLE_GRAPH_LENGTH,
        //               height: WHOLE_GRAPH_LENGTH)
        
                           .background {
                               Color.red.opacity(0.9)
                           }
                           .ignoresSafeArea()
    }
}


struct StitchUIScrollView<Content: View>: UIViewRepresentable {
    let contentSize: CGSize
    let document: StitchDocumentViewModel
    var content: Content
    
    init(contentSize: CGSize,
         document: StitchDocumentViewModel,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.contentSize = contentSize
        self.document = document
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        log("StitchUIScrollView: makeUIView")
        let scrollView = UIScrollView()
        
        // Enable zooming
        scrollView.minimumZoomScale = MIN_GRAPH_SCALE // 0.1
        scrollView.maximumZoomScale = MAX_GRAPH_SCALE //5.0
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
        
        scrollView.contentSize = contentSize
        
        // TODO: DEC 12: Did this cause any manual UIPanGesture change of contentOffset on a zoomed view to become super buggy?
        
        // TODO: DEC 12: initialize with proper persisted localPosition; using WHOLE_GRAPH_LENGTH/2 if it's a brand new project
        
        self.initializeContentOffset(scrollView)
        
        
        return scrollView
    }
    
    private func initializeContentOffset(_ scrollView: UIScrollView) {
        // ALSO: NOTE: CAREFUL: LOCAL POSITION IS STILL PERSISTED
        
                // Center the content
        DispatchQueue.main.async {
//            let newOffset =  CGPoint(x: max(0, (contentSize.width - scrollView.bounds.width) / 2),
//                                     y: max(0, (contentSize.height - scrollView.bounds.height) / 2))
            let newOffset =  CGPoint(x: WHOLE_GRAPH_LENGTH/2,
                                     y: WHOLE_GRAPH_LENGTH/2)
            
            //                    scrollView.contentOffset = newOffset
            
//            let newOffset =  CGPoint(x: 500, y: 500)
//            let newOffset =  CGPoint(x: 1500, // moves whole graph WEST
//                                     y: 20) // moves whole graph NORTH
            
            scrollView.setContentOffset(newOffset, animated: false)
            //                    dispatch(GraphScrolledViaUIScrollView(newOffset: newOffset))
            
            document.graphUI.uiScrollViewHasBeenInitialized = true
            
            dispatch(GraphScrollDataUpdated(
                newOffset: newOffset,
                newZoom: scrollView.zoomScale
            ))
        }
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        log("StitchUIScrollView: updateUIView")
        
        // Update content when SwiftUI view changes
        context.coordinator.hostingController.rootView = content
        
        
        if let canvasJumpLocation = document.graphUI.canvasJumpLocation {
            
            log("StitchUIScrollView: updateUIView: had canvasJumpLocation: \(canvasJumpLocation)")
            
            // Jump
            uiView.setContentOffset(canvasJumpLocation,
                                    animated: true)
            
            // and then set nil
            document.graphUI.canvasJumpLocation = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(content: content,
                           contentSize: contentSize,
                           document: document)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        
        let hostingController: UIHostingController<Content>
        
        // Used during spacebar + trackpad click-&-drag gesture
        private var initialContentOffset: CGPoint = .zero
        
        // Used for border checking
        private var previousContentOffset: CGPoint = .zero
        
        private let contentSize: CGSize
        
        weak var document: StitchDocumentViewModel?
        
        init(content: Content,
             contentSize: CGSize,
             document: StitchDocumentViewModel) {
            self.hostingController = UIHostingController(rootView: content)
            self.hostingController.view.backgroundColor = .clear
            self.contentSize = contentSize
            self.document = document
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            log("StitchUIScrollView: gestureRecognizer: shouldRecognizeSimultaneouslyWith")
            return true
        }
                
        // UIScrollViewDelegate method for zooming
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let contentOffset = scrollView.contentOffset
            let contentSize = scrollView.contentSize
            let scale = scrollView.zoomScale
            log("StitchUIScrollView: scrollViewDidZoom contentOffset: \(contentOffset)")
            log("StitchUIScrollView: scrollViewDidZoom contentSize: \(contentSize)")
            log("StitchUIScrollView: scrollViewDidZoom scale: \(scale)")

            
            // TODO: DEC 12: dragging a canvas item seems to already take into account the zoom level; except where we somehow come into cases where nodes move slower than cursor
            //            dispatch(GraphZoomUpdated(newZoom: scrollView.zoomScale))
            dispatch(GraphScrollDataUpdated(
                newOffset: scrollView.contentOffset,
                newZoom: scrollView.zoomScale
            ))
            
            //            scrollView
            
            //            // causes `updateUIView` to fire
            //            self.parent.zoomScale = scrollView.zoomScale
            //
            //            self.centerContent(scrollView: scrollView)
        }
        
        // TODO: DEC 12: use graph bounds checking logic here
        
        // Only called when scroll first begins; not DURING scroll
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            let contentOffset = scrollView.contentOffset
            log("StitchUIScrollView: scrollViewWillBeginDragging contentOffset: \(contentOffset)")
            log("StitchUIScrollView: scrollViewWillBeginDragging scrollView.zoomScale: \(scrollView.zoomScale)")
            dispatch(GraphScrollDataUpdated(
                newOffset: scrollView.contentOffset,
                newZoom: scrollView.zoomScale
            ))
        }
        
        func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
            let contentOffset = scrollView.contentOffset
            log("StitchUIScrollView: scrollViewWillBeginDecelerating contentOffset: \(contentOffset)")
            log("StitchUIScrollView: scrollViewWillBeginDecelerating scrollView.zoomScale: \(scrollView.zoomScale)")
            dispatch(GraphScrollDataUpdated(
                newOffset: scrollView.contentOffset,
                newZoom: scrollView.zoomScale
            ))
        }
                
        // Can you limit the scrolling here?
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentOffset = scrollView.contentOffset
            let contentSize = scrollView.contentSize
            let scale = scrollView.zoomScale
            let windowWidth = self.document?.graphUI.frame.width ?? .zero
            log("StitchUIScrollView: scrollViewDidScroll windowWidth: \(windowWidth)")
            log("StitchUIScrollView: scrollViewDidScroll contentOffset.x: \(contentOffset.x)")
            log("StitchUIScrollView: scrollViewDidScroll contentSize.width: \(contentSize.width)")
//            log("StitchUIScrollView: scrollViewDidScroll bounds: \(bounds)")
//            log("StitchUIScrollView: scrollViewDidScroll origin: \(origin)")
            log("StitchUIScrollView: scrollViewDidScroll scrollView.zoomScale: \(scrollView.zoomScale)")
            
            
            let cache = self.document?.graph.visibleNodesViewModel.infiniteCanvasCache ?? .init()
            
            // Only check borders etc. if we have cached size and position data for the nodes
            guard let westNode = self.document?.graph.westernMostNodeForBorderCheck(),
                  let eastNode = self.document?.graph.easternMostNodeForBorderCheck(),
                  let westBounds = cache.get(westNode.id),
                  let eastBounds = cache.get(eastNode.id),
                  let northNode = self.document?.graph.northernMostNodeForBorderCheck(),
                  let southNode = self.document?.graph.southernMostNodeForBorderCheck(),
                  let northBounds = cache.get(northNode.id),
                  let southBounds = cache.get(southNode.id) else {
                
                self.previousContentOffset = scrollView.contentOffset
                
                dispatch(GraphScrollDataUpdated(
                    newOffset: scrollView.contentOffset,
                    newZoom: scrollView.zoomScale
                ))
                
                return
            }
            
            
            let screenWidth = self.document?.graphUI.frame.width ?? .zero
            let screenHeight = self.document?.graphUI.frame.height ?? .zero
            
            let westernMostNodeCachedBoundsOriginX: CGFloat = westBounds.origin.x
            let easternMostNodeCachedBoundsOriginX: CGFloat = eastBounds.origin.x
            
            // ?? North will be the 'minimum contentOffset'
            let northernMostNodeCachedBoundsOriginY: CGFloat = northBounds.origin.y
            let southernMostNodeCachedBoundsOriginY: CGFloat = southBounds.origin.y
            
            log("StitchUIScrollView: scrollViewDidScroll: westernMostNodeCachedBoundsOriginX: \(westernMostNodeCachedBoundsOriginX)")
            log("StitchUIScrollView: scrollViewDidScroll: easternMostNodeCachedBoundsOriginX: \(easternMostNodeCachedBoundsOriginX)")
            log("StitchUIScrollView: scrollViewDidScroll: northernMostNodeCachedBoundsOriginY: \(northernMostNodeCachedBoundsOriginY)")
            log("StitchUIScrollView: scrollViewDidScroll: southernMostNodeCachedBoundsOriginY: \(southernMostNodeCachedBoundsOriginY)")

            // Minimum contentOffset can never be less than 0
            // But setting to be exactly 0 is awkward? We don't scroll back?
//            let minimumContentOffsetX = max(0, (westernMostNodeCachedBoundsOriginX * scale) - screenWidth)
            let minimumContentOffsetX = (westernMostNodeCachedBoundsOriginX * scale) - screenWidth
            let maximumContentOffsetX = easternMostNodeCachedBoundsOriginX * scale
            
//            let minimumContentOffsetY = max(0, (northernMostNodeCachedBoundsOriginY * scale) - screenHeight)
            let minimumContentOffsetY = (northernMostNodeCachedBoundsOriginY * scale) - screenHeight
            let maximumContentOffsetY = southernMostNodeCachedBoundsOriginY * scale
            
            log("StitchUIScrollView: scrollViewDidScroll: minimumContentOffsetX: \(minimumContentOffsetX)")
            log("StitchUIScrollView: scrollViewDidScroll: maximumContentOffsetX: \(maximumContentOffsetX)")
            let westernMostNodeAtEasternScreenEdge = scrollView.contentOffset.x <= minimumContentOffsetX
            let easternMostNodeAtWesternScreenEdge = scrollView.contentOffset.x >= maximumContentOffsetX
            log("StitchUIScrollView: scrollViewDidScroll: westernMostNodeAtEasternScreenEdge: \(westernMostNodeAtEasternScreenEdge)")
            log("StitchUIScrollView: scrollViewDidScroll: easternMostNodeAtWesternScreenEdge: \(easternMostNodeAtWesternScreenEdge)")
            
            // Might need to flip these? I forget
            let northernMostNodeAtSouthernScreenEdge = scrollView.contentOffset.y <= minimumContentOffsetY
            
            // southern most node at screen's top edge should actually be the minimum content offset ?; we
            let southernMostNodeAtNorthernScreenEdge = scrollView.contentOffset.y >= maximumContentOffsetY

            log("StitchUIScrollView: scrollViewDidScroll: minimumContentOffsetY: \(minimumContentOffsetY)")
            log("StitchUIScrollView: scrollViewDidScroll: maximumContentOffsetY: \(maximumContentOffsetY)")
            log("StitchUIScrollView: scrollViewDidScroll: northernMostNodeAtSouthernScreenEdge: \(northernMostNodeAtSouthernScreenEdge)")
            log("StitchUIScrollView: scrollViewDidScroll: southernMostNodeAtNorthernScreenEdge: \(southernMostNodeAtNorthernScreenEdge)")
            
            if westernMostNodeAtEasternScreenEdge {
                log("StitchUIScrollView: scrollViewDidScroll: hit min x offset")
                
                // NOTE: hit a bug one time here where we kept scrolling downward (contentOffset.y kept increasing) even after we had let go
                scrollView.setContentOffset(
                    .init(x: minimumContentOffsetX,
                          // reuse current scroll offset ?
                          y: scrollView.contentOffset.y),
                    animated: false)
            }
            
            else if easternMostNodeAtWesternScreenEdge {
                log("StitchUIScrollView: scrollViewDidScroll: hit max x offset")
                scrollView.setContentOffset(
                    .init(x: maximumContentOffsetX,
                          y: scrollView.contentOffset.y),
                    animated: false)
            }
            
            
            else if northernMostNodeAtSouthernScreenEdge {
                log("StitchUIScrollView: scrollViewDidScroll: hit min y offset")
                
                // NOTE: hit a bug one time here where we kept scrolling downward (contentOffset.y kept increasing) even after we had let go
                scrollView.setContentOffset(
                    .init(x: scrollView.contentOffset.x,
                          y: minimumContentOffsetY),
                    animated: false)
            }
            
            else if southernMostNodeAtNorthernScreenEdge {
                log("StitchUIScrollView: scrollViewDidScroll: hit max y offset")
                scrollView.setContentOffset(
                    .init(x: scrollView.contentOffset.x,
                          // reuse current scroll offset ?
                          y: maximumContentOffsetY),
                    animated: false)
            }
            
            // Can you actually check the borders here?
            // Can you STOP the scroll view's contentOffset from changing?
            // Would you need to
            // https://stackoverflow.com/questions/3410777/how-can-i-programmatically-force-stop-scrolling-in-a-uiscrollview
            
            self.previousContentOffset = scrollView.contentOffset
            
            dispatch(GraphScrollDataUpdated(
                newOffset: scrollView.contentOffset,
                newZoom: scrollView.zoomScale
            ))
            
            
        }
        
        // https://stackoverflow.com/a/30338969
        
//        // This STOPS post-gesture acceleration/deceleration ?
//        func scrollViewWillEndDragging(_ scrollView: UIScrollView,
//                                       withVelocity velocity: CGPoint,
//                                       targetContentOffset: UnsafeMutablePointer<CGPoint>) {
//            log("StitchUIScrollView: scrollViewWillEndDragging scrollView.contentOffset: \(scrollView.contentOffset)")
//            log("StitchUIScrollView: scrollViewWillEndDragging scrollView.contentSize: \(scrollView.contentSize)")
//            log("StitchUIScrollView: scrollViewWillEndDragging scrollView.zoomScale: \(scrollView.zoomScale)")
//            targetContentOffset.pointee = scrollView.contentOffset
//        }
        
       
        
        
        
        // TODO: DEC 12: fix the boundary checking logic here; why did it work in simpler ChatGPT app but not here?
        // TODO: DEC 12: ??: when gesture ends, animate toward some predicted-end-point ? Or kick off legacy momentum calculations?
        
        // Handle pan gesture with boundary checks
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            
            let spaceHeld = document?.keypressState.isSpacePressed ?? false
            
            log("StitchUIScrollView: handlePan: spaceHeld: \(spaceHeld)")
            
            guard let scrollView = gesture.view as? UIScrollView else {
                return
            }
            
            guard spaceHeld else {
                return
            }
            
            let translation = gesture.translation(in: scrollView)
            
            log("StitchUIScrollView: handlePan: translation: \(translation)")
            
            switch gesture.state {
                
            case .began:
                initialContentOffset = scrollView.contentOffset
                
                document?.graphUI.activeSpacebarClickDrag = true
                
            case .changed:
                document?.graphUI.activeSpacebarClickDrag = true
                
                // something about this not quite right vs simpler PureZoom
                var newX = initialContentOffset.x - translation.x
                var newY = initialContentOffset.y - translation.y
                if newX < 0 { newX = 0 }
                if newY < 0 { newY = 0 }
                
                //                let maxX = 12500.0
                //                let maxY = 13200.0
                // this depends on zoom level
                // correct for max zoom out
                let maxX: CGFloat = 1250
                let maxY: CGFloat = 2000
                if newX > maxX {
                    newX = maxX
                }
                if newY > maxY {
                    newY = maxY
                }
                
                let newOffset = CGPoint(
                    x: min(max(0, initialContentOffset.x - translation.x),
                           contentSize.width - scrollView.bounds.width),
                    y: min(max(0, initialContentOffset.y - translation.y),
                           contentSize.height - scrollView.bounds.height)
                )
                //                log("handlePan: newOffset: \(newOffset)")
                log("StitchUIScrollView: handlePan: newOffset.x: \(newOffset.x)")
                log("StitchUIScrollView: handlePan: newOffset.y: \(newOffset.y)")
                
                let _newOffset = CGPoint.init(x: newX, y: newY)
                log("StitchUIScrollView: handlePan: _newOffset.x: \(_newOffset.x)")
                log("StitchUIScrollView: handlePan: _newOffset.y: \(_newOffset.y)")
                
                // max x seems to be 12547.00390625, `12500`
                // max y seems 13231.203125 i.e. `13200`
                
                //                scrollView.setContentOffset(newOffset,
                scrollView.setContentOffset(_newOffset,
                                            animated: false)
                
                dispatch(GraphScrollDataUpdated(
                    newOffset: _newOffset, //scrollView.contentOffset,
                    newZoom: scrollView.zoomScale
                ))
                
                
            case .possible:
                
                log("StitchUIScrollView: handlePan: possible")
                
                
            case .ended, .cancelled, .failed:
                
                document?.graphUI.activeSpacebarClickDrag = false
                
                log("StitchUIScrollView: handlePan: ended/cancelled/failed")
                
                scrollView.setContentOffset(scrollView.contentOffset,
                                            animated: false)
                
                // DO WE HAVE NATURAL MOMENTUM WHEN WE LET GO ?
                dispatch(GraphScrollDataUpdated(
                    newOffset: scrollView.contentOffset,
                    newZoom: scrollView.zoomScale
                ))
                
            @unknown default:
                
                log("StitchUIScrollView: handlePan: default")
            }
            
            
        }
    }
}

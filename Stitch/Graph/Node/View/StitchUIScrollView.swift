//
//  StitchUIScrollView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/12/24.
//

import SwiftUI

// TODO: every zoom in/out jumps is 0.25, but the second-to-last zoom out jump feels too big?
let ZOOM_COMMAND_RATE: CGFloat = 0.25
//let ZOOM_COMMAND_RATE: CGFloat = 0.1
//let ZOOM_COMMAND_RATE: CGFloat = 0.175
    
//let WHOLE_GRAPH_LENGTH: CGFloat = 30000 // 30,000 x 30,000
let WHOLE_GRAPH_LENGTH: CGFloat = 300000 // 300,000 x 300,000

let WHOLE_GRAPH_SIZE = CGSize(width: WHOLE_GRAPH_LENGTH,
                              height: WHOLE_GRAPH_LENGTH)

let WHOLE_GRAPH_COORDINATE_SPACE = "WHOLE_GRAPH_COORDINATE_SPACE"

struct StitchUIScrollViewModifier: ViewModifier {
    let document: StitchDocumentViewModel
    
    @MainActor
    var selectionState: GraphUISelectionState {
        document.graphUI.selection
    }
    
    func body(content: Content) -> some View {
        StitchUIScrollView(contentSize: WHOLE_GRAPH_SIZE, document: document) {
            ZStack {
                content
                    .ignoresSafeArea()
                
//                Color.blue.opacity(0.9)
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
                            dispatch(GraphTappedAction())
                        }))
                
                    .gesture(StitchLongPressGestureRecognizerRepresentable())
                    .gesture(StitchTrackpadGraphBackgroundPanGesture())
                
                // RENDERING THE NODE CURSOR SELECTION BOX HERE
                
                // Selection box and cursor
                if let expansionBox = selectionState.expansionBox {
                    ExpansionBoxView(graph: document.graph,
                                     box: expansionBox)
                }
                
                if selectionState.isSelecting,
                   let currentDrag = selectionState.dragCurrentLocation {
                    CursorDotView(
                        currentDragLocation: currentDrag,
                        isFingerOnScreenSelection: selectionState.isFingerOnScreenSelection,
                        scale: document.graphMovement.zoomData.final)
                }
            } // ZStack
        } // StitchUIScrollView
        
        .background {
            //Color.red.opacity(0.9)
            APP_BACKGROUND_COLOR
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
                
        self.initializeContentOffset(scrollView)
                
        return scrollView
    }
    
    private func initializeContentOffset(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            let newOffset =  CGPoint(x: WHOLE_GRAPH_LENGTH/2,
                                     y: WHOLE_GRAPH_LENGTH/2)
            scrollView.setContentOffset(newOffset, animated: false)
            dispatch(GraphScrollDataUpdated(
                newOffset: newOffset,
                newZoom: scrollView.zoomScale
            ))
        }
    }
    

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Update content when SwiftUI view changes
        context.coordinator.hostingController.rootView = content
        
        if let canvasJumpLocation = document.graphUI.canvasJumpLocation {
            uiView.setContentOffset(canvasJumpLocation, animated: true)
            dispatch(GraphScrollDataUpdated(
                newOffset: uiView.contentOffset,
                newZoom: uiView.zoomScale
            ))
            document.graphUI.canvasJumpLocation = nil
        }
        
        if document.graphUI.canvasZoomedIn {
            uiView.zoomScale += ZOOM_COMMAND_RATE
            dispatch(GraphScrollDataUpdated(
                newOffset: uiView.contentOffset,
                newZoom: uiView.zoomScale
            ))
            document.graphUI.canvasZoomedIn = false
        }
        
        if document.graphUI.canvasZoomedOut {
            uiView.zoomScale -= ZOOM_COMMAND_RATE
            dispatch(GraphScrollDataUpdated(
                newOffset: uiView.contentOffset,
                newZoom: uiView.zoomScale
            ))
            document.graphUI.canvasZoomedOut = false
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
        //        private var previousContentOffset: CGPoint = .zero
        
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
            dispatch(GraphScrollDataUpdated(
                newOffset: scrollView.contentOffset,
                newZoom: scrollView.zoomScale
            ))
        }
        
        // Only called when scroll first begins; not DURING scroll
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            dispatch(GraphScrollDataUpdated(
                newOffset: scrollView.contentOffset,
                newZoom: scrollView.zoomScale
            ))
        }
        
        func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
            dispatch(GraphScrollDataUpdated(
                newOffset: scrollView.contentOffset,
                newZoom: scrollView.zoomScale
            ))
        }
                
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.checkBorder(scrollView)
        }
        
        func checkBorder(_ scrollView: UIScrollView) {
            
            let scale = scrollView.zoomScale
            let cache = self.document?.graph.visibleNodesViewModel.infiniteCanvasCache ?? .init()
            
            // Only check borders etc. if we have cached size and position data for the nodes
            guard let canvasItemsInFrame = self.document?.graph.getVisibleCanvasItems().filter(\.isVisibleInFrame),
                  let westNode = self.document?.graph.westernMostNodeForBorderCheck(canvasItemsInFrame),
                  let eastNode = self.document?.graph.easternMostNodeForBorderCheck(canvasItemsInFrame),
                  let westBounds = cache.get(westNode.id),
                  let eastBounds = cache.get(eastNode.id),
                  let northNode = self.document?.graph.northernMostNodeForBorderCheck(canvasItemsInFrame),
                  let southNode = self.document?.graph.southernMostNodeForBorderCheck(canvasItemsInFrame),
                  let northBounds = cache.get(northNode.id),
                  let southBounds = cache.get(southNode.id) else {
                
                dispatch(GraphScrollDataUpdated(
                    newOffset: scrollView.contentOffset,
                    newZoom: scrollView.zoomScale
                ))
            
                // log("StitchUIScrollView: scrollViewDidScroll: MISSING WEST, EAST, SOUTH OR NORTH IN-FRAME NODES OR BOUNDS")
                
                return
            }
            
            let screenWidth = self.document?.graphUI.frame.width ?? .zero
            let screenHeight = self.document?.graphUI.frame.height ?? .zero
            
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
            } else if easternMostNodeAtWesternScreenEdge {
                log("StitchUIScrollView: scrollViewDidScroll: hit max x offset")
                finalContentOffsetX = maximumContentOffsetX
                hitBorder = true
            }
            
            if northernMostNodeAtSouthernScreenEdge {
                log("StitchUIScrollView: scrollViewDidScroll: hit min y offset")
                finalContentOffsetY = minimumContentOffsetY
                hitBorder = true
            } else if southernMostNodeAtNorthernScreenEdge {
                log("StitchUIScrollView: scrollViewDidScroll: hit max y offset")
                finalContentOffsetY = maximumContentOffsetY
                hitBorder = true
            }
            
            // `setContentOffset` interrupts UIScrollView's momentum, so we only do it if we actually hit a border
            if hitBorder {
                log("StitchUIScrollView: scrollViewDidScroll: hit border")
                let finalOffset = CGPoint(x: finalContentOffsetX, y: finalContentOffsetY)
                scrollView.setContentOffset(finalOffset, animated: false)
                dispatch(GraphScrollDataUpdated(
                    newOffset: finalOffset,
                    newZoom: scrollView.zoomScale
                ))
            } else {
                dispatch(GraphScrollDataUpdated(
                    newOffset: scrollView.contentOffset,
                    newZoom: scrollView.zoomScale
                ))
            }
        }
                
        // Handle pan gesture with boundary checks
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let spaceHeld = document?.keypressState.isSpacePressed ?? false
            
            guard let scrollView = gesture.view as? UIScrollView else {
                return
            }
            
            guard spaceHeld else {
                return
            }
            
            let translation = gesture.translation(in: scrollView)
                        
            switch gesture.state {

            case .began:
                initialContentOffset = scrollView.contentOffset
                document?.graphUI.activeSpacebarClickDrag = true

            case .changed:
                document?.graphUI.activeSpacebarClickDrag = true
                
                let screenHeight = self.document?.graphUI.frame.height ?? .zero
                let screenWidth = self.document?.graphUI.frame.width ?? .zero
                
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
                document?.graphUI.activeSpacebarClickDrag = false
                scrollView.setContentOffset(scrollView.contentOffset,
                                            animated: false)
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

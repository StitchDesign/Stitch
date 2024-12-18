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
                //                        .gesture(StitchLongPressGestureRecognizerRepresentable())
                
                //                        .gesture(StitchLongPressGestureRecognizerRepresentable())
                
                // THIS IS BETTER: HANDLES BOTH ZOOMING AND SCROLLING PROPERLY
                
                    .gesture(StitchTrackpadGraphBackgroundPanGesture())
                
                
                // RENDERING THE NODE CURSOR SELECTION BOX HERE
                
                // Selection box and cursor
                if let expansionBox = selectionState.expansionBox {
                    ExpansionBoxView(graph: document.graph,
                                     box: expansionBox,
                                     scale: document.graphMovement.zoomData.final)
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

struct StitchLongPressGestureRecognizerRepresentable: UIGestureRecognizerRepresentable {
    
    func makeUIGestureRecognizer(context: Context) -> some UIGestureRecognizer {
        log("StitchLongPressGestureRecognizerRepresentable: makeUIGestureRecognizer")
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.5 // half a second
        
        // if not restricted to screen, can be recognized via long-press too
        // maybe force disable that on Catalyst?
        recognizer.allowedTouchTypes = [SCREEN_TOUCH_ID]
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UIGestureRecognizerType,
                                         context: Context) {
        
        log("StitchLongPressGestureRecognizerRepresentable: handleUIGestureRecognizerAction")
        
        switch recognizer.state {
            
        case .began:
            if let view = recognizer.view {
                let location = recognizer.location(in: view)
                log("StitchLongPressGestureRecognizerRepresentable: handleUIGestureRecognizerAction: BEGAN: location: \(location)")
                // Use an action to avoid having to worry about `weak var` vs `let` with StitchDocumentViewModel ?
                dispatch(GraphBackgroundLongPressed(location: location))
            }
            
        case .changed:
            let location = recognizer.location(in: recognizer.view)
            log("StitchLongPressGestureRecognizerRepresentable: handleUIGestureRecognizerAction: CHANGED: location: \(location)")
            dispatch(GraphDraggedDuringSelection(location: location))
            
        case .ended, .cancelled:
            log("StitchLongPressGestureRecognizerRepresentable: handleUIGestureRecognizerAction: ENDED/CANCELLED")
            dispatch(GraphBackgroundLongPressEnded())
            
        default:
            break
        }
    }
}



struct StitchTrackpadGraphBackgroundPanGesture: UIGestureRecognizerRepresentable {
    
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        
        log("StitchTrackpadGraphBackgroundPanGesture: makeUIGestureRecognizer")
        
        let delegate = context.coordinator
        
        let trackpadPanGesture = UIPanGestureRecognizer(
            target: delegate,
            action: #selector(delegate.trackpadPanInView))
        
        // Only listen to click and drag from mouse
        trackpadPanGesture.allowedScrollTypesMask = [.discrete]
        // ignore screen; uses trackpad
        trackpadPanGesture.allowedTouchTypes = [TRACKPAD_TOUCH_ID]
        // 1 touch ensures a click and drag event
        trackpadPanGesture.minimumNumberOfTouches = 1
        trackpadPanGesture.maximumNumberOfTouches = 1
        trackpadPanGesture.delegate = delegate
        
        return trackpadPanGesture
    }
    
    
    typealias UIGestureRecognizerType = UIPanGestureRecognizer
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: StitchTrackpadGraphBackgroundPanGesture
        
        var shiftHeld: Bool = false
        
        init(parent: StitchTrackpadGraphBackgroundPanGesture) {
            self.parent = parent
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            log("StitchTrackpadGraphBackgroundPanGesture: gestureRecognizer: shouldRecognizeSimultaneouslyWith")
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldReceive event: UIEvent) -> Bool {
            log("StitchTrackpadGraphBackgroundPanGesture: gestureRecognizer: should receive event")
            if event.modifierFlags.contains(.shift) {
                log("StitchTrackpadGraphBackgroundPanGesture: SHIFT DOWN")
                self.shiftHeld = true
            } else {
                log("StitchTrackpadGraphBackgroundPanGesture: SHIFT NOT DOWN")
                self.shiftHeld = false
            }
            
            return true
        }
        
        @objc func trackpadPanInView(_ gestureRecognizer: UIPanGestureRecognizer) {
            log("StitchTrackpadGraphBackgroundPanGesture: trackpadPanInView recognized")
            
            log("StitchTrackpadGraphBackgroundPanGesture: handleUIGestureRecognizerAction")
            
            let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
            let location = gestureRecognizer.location(in: gestureRecognizer.view)
            let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)
            
            log("StitchTrackpadGraphBackgroundPanGesture: handleUIGestureRecognizerAction: gestureRecognizer.state.description: \(gestureRecognizer.state.description)")
            
            log("StitchTrackpadGraphBackgroundPanGesture: handleUIGestureRecognizerAction: location: \(location)")
            
            dispatch(GraphBackgroundTrackpadDragged(
                translation: translation.toCGSize,
                location: location,
                velocity: velocity,
                numberOfTouches: gestureRecognizer.numberOfTouches,
                gestureState: gestureRecognizer.state,
                shiftHeld: self.shiftHeld))
            
        }
    }
    
}

// UIScrollView's zooming also updates contentOffset,
// so we prefer to update both localPosition and zoomData at same time.
struct GraphScrollDataUpdated: StitchDocumentEvent {
    let newOffset: CGPoint
    let newZoom: CGFloat
    
    func handle(state: StitchDocumentViewModel) {
        log("GraphScrolledViaUIScrollView: newOffset: \(newOffset)")
        log("GraphZoomUpdated: newZoom: \(newZoom)")
        state.graphMovement.localPosition = newOffset
        state.graphMovement.zoomData.final = newZoom
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
        
        // ALSO: NOTE: CAREFUL: LOCAL POSITION IS STILL PERSISTED
        
        // Center the content
        //        DispatchQueue.main.async {
        //            let newOffset =  CGPoint(x: max(0, (contentSize.width - scrollView.bounds.width) / 2),
        //                                     y: max(0, (contentSize.height - scrollView.bounds.height) / 2))
        //            scrollView.contentOffset = newOffset
        //            dispatch(GraphScrolledViaUIScrollView(newOffset: newOffset))
        //        }
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        log("StitchUIScrollView: updateUIView")
        
        // Update content when SwiftUI view changes
        context.coordinator.hostingController.rootView = content
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(content: content,
                           contentSize: contentSize,
                           document: document)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        
        let hostingController: UIHostingController<Content>
        
        private var initialContentOffset: CGPoint = .zero
        
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
        
        //        var shiftHeld: Bool = false
        
        // SHOULD NOT BE NEEDED
        //        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
        //                               shouldReceive event: UIEvent) -> Bool {
        //             log("StitchUIScrollView: gestureRecognizer: should receive event")
        //            if event.modifierFlags.contains(.shift) {
        //                 log("StitchUIScrollView: SHIFT DOWN")
        //                self.shiftHeld = true
        //            } else {
        //                 log("StitchUIScrollView: SHIFT NOT DOWN")
        //                self.shiftHeld = false
        //            }
        //
        //            return true
        //        }
        
        
        // UIScrollViewDelegate method for zooming
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            
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
        
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentOffset = scrollView.contentOffset
            let contentSize = scrollView.contentSize
            let bounds = scrollView.bounds.size
            let origin = scrollView.frame.origin
            log("StitchUIScrollView: scrollViewDidScroll contentOffset: \(contentOffset)")
            log("StitchUIScrollView: scrollViewDidScroll contentSize: \(contentSize)")
            log("StitchUIScrollView: scrollViewDidScroll bounds: \(bounds)")
            log("StitchUIScrollView: scrollViewDidScroll origin: \(origin)")
            log("StitchUIScrollView: scrollViewDidScroll scrollView.zoomScale: \(scrollView.zoomScale)")
            
            // TODO: DEC 12: revisit this after fixing input edits etc.
            dispatch(GraphScrollDataUpdated(
                newOffset: scrollView.contentOffset,
                newZoom: scrollView.zoomScale
            ))
        }
        
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

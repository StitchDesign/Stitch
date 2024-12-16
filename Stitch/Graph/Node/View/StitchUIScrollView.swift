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

struct StitchUIScrollViewModifier: ViewModifier {
    let document: StitchDocumentViewModel
    
    func body(content: Content) -> some View {
        StitchUIScrollView(contentSize: WHOLE_GRAPH_SIZE) {
            ZStack {
                content
                // places existing nodes in center like you expected before applying the UIScrollView
                // TODO: DEC 12: how to place existing nodes such that we imitate the old .offset of graph.localPosition ?
                
//                    .offset(x: WHOLE_GRAPH_LENGTH/2,
//                            y: WHOLE_GRAPH_LENGTH/2)
                
                
//                    .frame(width: WHOLE_GRAPH_LENGTH/2,
//                           height: WHOLE_GRAPH_LENGTH/2)
//                    .frame(width: WHOLE_GRAPH_LENGTH,
//                           height: WHOLE_GRAPH_LENGTH)
                    .ignoresSafeArea()
                
                Color.blue.opacity(0.9).zIndex(-99999)
                    .frame(WHOLE_GRAPH_SIZE)
                    .ignoresSafeArea()
                    .gesture(SpatialTapGesture(count: 2,
                                               coordinateSpace: .global)
                        .onEnded({ value in
                            dispatch(GraphDoubleTappedAction(location: value.location))
                        })
                    )
                    .simultaneousGesture(TapGesture(count: 1)
                        .onEnded({
                            dispatch(GraphTappedAction())
                        }))
            }
            
        }
        
        // VERY BAD
//        .frame(width: WHOLE_GRAPH_LENGTH,
//               height: WHOLE_GRAPH_LENGTH)
        
        .background {
            Color.red.opacity(0.9)
        }
        .ignoresSafeArea()
    }
}

struct GraphZoomUpdated: StitchDocumentEvent {
    let newZoom: CGFloat // from UIScrollView
    
    func handle(state: StitchDocumentViewModel) {
        log("GraphZoomUpdated: newZoom: \(newZoom)")
        state.graphMovement.zoomData.final = newZoom
    }
}


struct GraphScrolledViaUIScrollView: StitchDocumentEvent {
    let newOffset: CGPoint
    
    func handle(state: StitchDocumentViewModel) {
        log("GraphScrolledViaUIScrollView: newOffset: \(newOffset)")
        state.graphMovement.localPosition = newOffset
    }
}

struct StitchUIScrollView<Content: View>: UIViewRepresentable {
    var content: Content
    let contentSize: CGSize

    init(contentSize: CGSize,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.contentSize = contentSize
    }

    func makeUIView(context: Context) -> UIScrollView {
        log("StitchUIScrollView: makeUIView")
        let scrollView = UIScrollView()

        // Enable zooming
        scrollView.minimumZoomScale = MIN_GRAPH_SCALE // 0.1
        scrollView.maximumZoomScale = MAX_GRAPH_SCALE //5.0
        scrollView.delegate = context.coordinator

        // Enable gestures
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleLongPress(_:)))
        scrollView.addGestureRecognizer(longPressGesture)
        
        // TODO: DEC 12: only should fire when spacebar held; also, super buggy, seems to reset any
//        // Only use with MacCatalyst
//#if targetEnvironment(macCatalyst)
//        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePan(_:)))
//        scrollView.addGestureRecognizer(panGesture)
//#endif

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
        
        // Center the content
        DispatchQueue.main.async {
            let newOffset =  CGPoint(x: max(0, (contentSize.width - scrollView.bounds.width) / 2),
                                     y: max(0, (contentSize.height - scrollView.bounds.height) / 2))
            scrollView.contentOffset = newOffset
            dispatch(GraphScrolledViaUIScrollView(newOffset: newOffset))
        }
        
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        log("StitchUIScrollView: updateUIView")
        
        // Update content when SwiftUI view changes
        context.coordinator.hostingController.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(content: content, contentSize: contentSize)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>
        private var initialContentOffset: CGPoint = .zero
        private let contentSize: CGSize
        
        init(content: Content, contentSize: CGSize) {
            self.hostingController = UIHostingController(rootView: content)
            self.hostingController.view.backgroundColor = .clear
            self.contentSize = contentSize
        }

        // UIScrollViewDelegate method for zooming
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            
            // TODO: DEC 12: dragging a canvas item seems to already take into account the zoom level; except where we somehow come into cases where nodes move slower than cursor
//            dispatch(GraphZoomUpdated(newZoom: scrollView.zoomScale))
            
            
//            // causes `updateUIView` to fire
//            self.parent.zoomScale = scrollView.zoomScale
//            
//            self.centerContent(scrollView: scrollView)
        }
        
        // TODO: DEC 12: use graph bounds checking logic here
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            let contentOffset = scrollView.contentOffset
            log("scrollViewWillBeginDragging contentOffset: \(contentOffset)")
        }
        
        func scrollWillBeginDecelerating(_ scrollView: UIScrollView) {
            let contentOffset = scrollView.contentOffset
            log("scrollWillBeginDecelerating contentOffset: \(contentOffset)")
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentOffset = scrollView.contentOffset
            let contentSize = scrollView.contentSize
            let bounds = scrollView.bounds.size
            log("scrollViewDidScroll contentOffset: \(contentOffset)")
            log("scrollViewDidScroll contentSize: \(contentSize)")
            log("scrollViewDidScroll bounds: \(bounds)")
            // TODO: DEC 12: revisit this after fixing input edits etc.
            dispatch(GraphScrolledViaUIScrollView(newOffset: contentOffset))
        }
        
        
        
        // TODO: DEC 12: should start and update active node selection cursor box
        
        // Handle long press gesture
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                print("Long press detected")
            }
        }

        // Handle pan gesture with boundary checks
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            
            let translation = gesture.translation(in: scrollView)
            if gesture.state == .began {
                initialContentOffset = scrollView.contentOffset
            } else if gesture.state == .changed {
                
                // something about this not quite right vs simpler PureZoom
                
                var newX = initialContentOffset.x - translation.x
                var newY = initialContentOffset.y - translation.y
                
                if newX < 0 {
                    newX = 0
                }
                
                if newY < 0 {
                    newY = 0
                }
                
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
                log("handlePan: newOffset.x: \(newOffset.x)")
                log("handlePan: newOffset.y: \(newOffset.y)")
                
                let _newOffset = CGPoint.init(x: newX, y: newY)
                log("handlePan: _newOffset.x: \(_newOffset.x)")
                log("handlePan: _newOffset.y: \(_newOffset.y)")
                
                // max x seems to be 12547.00390625, `12500`
                // max y seems 13231.203125 i.e. `13200`
                
//                scrollView.setContentOffset(newOffset,
                scrollView.setContentOffset(_newOffset,
                                            animated: false)
            }
        }
    }
}

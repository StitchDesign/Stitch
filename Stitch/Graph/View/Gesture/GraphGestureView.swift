//
//  GraphPanGestureView.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/23/22.
//

import SwiftUI
import StitchSchemaKit

// MUST LISTEN FOR KEY PRESSES ON GraphGesture as well, otherwise selecting a node stops key presses.

typealias GraphGestureViewController = StitchHostingController
// typealias GraphGestureViewController = NoKeyPressHostingController

/// A wrapper view controller representable for the entire graph view. Handles scroll, pinch, and long press gestures.
struct GraphGestureView<T: View>: UIViewControllerRepresentable {
    // Pass in reference to access handlers for graph movement
    let document: StitchDocumentViewModel
    @ViewBuilder var view: () -> T

    func makeUIViewController(context: Context) -> GraphGestureViewController<T> {
        let vc = GraphGestureViewController(
            rootView: view(),
            ignoresSafeArea: true,
            //            ignoreKeyCommands: true,
            ignoreKeyCommands: false,
            name: "GraphGestureView")

        let delegate = context.coordinator

        vc.view.tag = GESTURE_VIEW_TAG

        // Tracks scroll events with scroll wheel and trackpad
        let trackpadPanGesture = UIPanGestureRecognizer(
            target: delegate,
            action: #selector(delegate.trackpadPanInView))
        trackpadPanGesture.allowedScrollTypesMask = [.continuous, .discrete]
        // ignore screen; uses trackpad
        trackpadPanGesture.allowedTouchTypes = [TRACKPAD_TOUCH_ID]
        trackpadPanGesture.maximumNumberOfTouches = 0
        trackpadPanGesture.delegate = delegate
        vc.view.addGestureRecognizer(trackpadPanGesture)

        let tapGesture = UITapGestureRecognizer(
            target: delegate,
            action: #selector(delegate.tapInView))
        tapGesture.delegate = delegate
        vc.view.addGestureRecognizer(tapGesture)

        /*
         Note: we allow single and double taps on graph to happen simultaneously,
         since otherwise there is a delay on single tap
         while we "wait to see if a single tap becomes a double tap."
         */
        return vc
    }

    func updateUIViewController(_ uiViewController: GraphGestureViewController<T>, context: Context) {
        uiViewController.rootView = view()
    }

    func makeCoordinator() -> GraphGestureDelegate {
        GraphGestureDelegate(document: document)
    }
}

class GraphGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let zoomScrollRate = 0.04
    
    weak var document: StitchDocumentViewModel?

    var commandHeldDown: Bool = false 
    
    init(document: StitchDocumentViewModel) {
        super.init()
        self.document = document
    }

    // Enables simultaneous gestures with SwiftUI gesture handlers
    // Pan gestures are cancelled by pinch gestures.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        // Disble other gestures if there's a pinch
        if Self.shouldDisableDueToPinchGesture(gestureRecognizer, otherGestureRecognizer: otherGestureRecognizer) ||
            Self.shouldDisableScroll(gestureRecognizer, otherGestureRecognizer: otherGestureRecognizer) {
            log("GraphGestureDelegate: disable gestures")
            otherGestureRecognizer.disableTemporarily()
            return false
        }

        return true
    }

    // Trackpad-based gestures
    @objc func trackpadPanInView(_ gestureRecognizer: UIPanGestureRecognizer) {
        self.trackpadGraphBackgroundPan(gestureRecognizer)
    }

    @objc func tapInView(_ gestureRecognizer: UITapGestureRecognizer) {
        // graph?.graphTappedDuringMouseScroll()
    }

    private static func shouldDisableDueToPinchGesture(_ gestureRecognizer: UIGestureRecognizer,
                                                       otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer is UIPinchGestureRecognizer &&
            gestureRecognizer.state == .began
    }

    private static func shouldDisableScroll(_ gestureRecognizer: UIGestureRecognizer,
                                            otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer is UITapGestureRecognizer &&
            gestureRecognizer.numberOfTouches == 0 &&   // node selection box stays working
            otherGestureRecognizer is UIPanGestureRecognizer
    }
}

//
//  GraphBackgroundGestureView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/14/22.
//

import SwiftUI
import StitchSchemaKit

// typealias GraphGestureBackgroundViewController = StitchHostingController
typealias GraphGestureBackgroundViewController = NoKeyPressHostingController

/// A view controller representable that listens for click-and-drag events used for selecting nodes
/// using a bounding box.
struct GraphGestureBackgroundView<T: View>: UIViewControllerRepresentable {
    // Passes in reference to GraphState to access gesture handlers
    let document: StitchDocumentViewModel
    @ViewBuilder var view: () -> T

    func makeUIViewController(context: Context) -> GraphGestureBackgroundViewController<T> {
        let vc = GraphGestureBackgroundViewController(
            rootView: view(),
            ignoresSafeArea: true,
            ignoreKeyCommands: true,
            name: "GraphGestureBackgroundView")

        let delegate = context.coordinator
                
        // Use a UIKit gesture which is limited to screen,
        // since a SwiftUI drag gesture will fire at the same time as the trackpad gesture and cannot be specfically limited to the screen.
        let screenPanGesture = UIPanGestureRecognizer(
            target: delegate,
            action: #selector(delegate.screenPanInView))

        screenPanGesture.allowedTouchTypes = [SCREEN_TOUCH_ID]
        screenPanGesture.delegate = delegate
        vc.view.addGestureRecognizer(screenPanGesture)
        
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
        vc.view.addGestureRecognizer(trackpadPanGesture)

        // TODO: no longer needed just for pseudo-modal dismissal?
        // screen only
        let longPressGesture = UILongPressGestureRecognizer(
            target: delegate,
            action: #selector(delegate.longPressInView))
        longPressGesture.minimumPressDuration = 0.5 // half a second
        longPressGesture.allowedTouchTypes = [SCREEN_TOUCH_ID]
        longPressGesture.delegate = delegate
        vc.view.addGestureRecognizer(longPressGesture)

        return vc
    }

    func updateUIViewController(_ uiViewController: GraphGestureBackgroundViewController<T>, context: Context) {
        uiViewController.rootView = view()
    }

    func makeCoordinator() -> NodeSelectionGestureRecognizer {
        NodeSelectionGestureRecognizer(document: document)
    }
}

final class NodeSelectionGestureRecognizer: NSObject, UIGestureRecognizerDelegate {
    weak var document: StitchDocumentViewModel?

    var shiftHeld: Bool = false
    
    init(document: StitchDocumentViewModel) {
        super.init()
        self.document = document
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive event: UIEvent) -> Bool {
        if event.modifierFlags.contains(.shift) {
            self.shiftHeld = true
        } else {
            self.shiftHeld = false
        }
        return true
    }
    
    @objc func longPressInView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            if let view = gestureRecognizer.view {
                let location = gestureRecognizer.location(in: view)
                dispatch(GraphBackgroundLongPressed(location: location))
            }
        case .ended, .cancelled:
            dispatch(GraphBackgroundLongPressEnded())
        default:
            break
        }
    }

    @objc func screenPanInView(_ gestureRecognizer: UIPanGestureRecognizer) {
        self.screenGraphBackgroundPan(gestureRecognizer)
    }

    // Trackpad-based gestures
    @MainActor
    @objc func trackpadPanInView(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
        let location = gestureRecognizer.location(in: gestureRecognizer.view)
        let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)

        self.document?.trackpadClickDrag(
            translation: translation.toCGSize,
            location: location,
            velocity: velocity,
            numberOfTouches: gestureRecognizer.numberOfTouches,
            gestureState: gestureRecognizer.state,
            shiftHeld: self.shiftHeld)
    }
}

//
//  PreviewElementTrackpadPanView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/14/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PreviewElementTrackpadPanView: UIViewControllerRepresentable {

    let interactiveLayer: InteractiveLayer
    let position: CGPoint
    let size: CGSize
    let parentSize: CGSize
    let document: StitchDocumentViewModel

    func makeUIViewController(context: Context) -> UIViewController {
        //        log("PreviewElementTrackpadPanView: makeUIViewController")

        let vc = UIViewController()

        let delegate = context.coordinator

        let trackpadPanGesture = UIPanGestureRecognizer(
            target: delegate,
            action: #selector(delegate.trackpadPanInView))

        trackpadPanGesture.allowedScrollTypesMask = [.discrete, .continuous]
        // ignore screen; uses trackpad
        trackpadPanGesture.allowedTouchTypes = [TRACKPAD_TOUCH_ID]
        trackpadPanGesture.maximumNumberOfTouches = 0

        trackpadPanGesture.delegate = delegate
        vc.view.addGestureRecognizer(trackpadPanGesture)

        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController,
                                context: Context) {

        //        log("PreviewElementTrackpadPanView: updateUIViewController")
        //        log("PreviewElementTrackpadPanView: position: \(position)")
        //        log("PreviewElementTrackpadPanView: size: \(size)")
        //        log("PreviewElementTrackpadPanView: parentSize: \(parentSize)")

        // `id` should never change during a preview window element's lifetime;
        // but its position, size, or parent size can change.
        context.coordinator.position = position
        context.coordinator.size = size
        context.coordinator.parentSize = parentSize
    }

    func makeCoordinator() -> PreviewElementTrackpadDelegate {
        //        log("PreviewElementTrackpadPanView: makeCoordinator")
        return PreviewElementTrackpadDelegate(
            interactiveLayer: interactiveLayer,
            position: position,
            size: size,
            parentSize: parentSize,
            document: document)
    }
}

class PreviewElementTrackpadDelegate: NSObject, UIGestureRecognizerDelegate {

    let interactiveLayer: InteractiveLayer
    var position: CGPoint
    var size: CGSize
    var parentSize: CGSize
    weak var document: StitchDocumentViewModel?

    init(interactiveLayer: InteractiveLayer,
         position: CGPoint,
         size: CGSize,
         parentSize: CGSize,
         document: StitchDocumentViewModel) {

        //        log("PreviewElementTrackpadDelegate: init")

        self.interactiveLayer = interactiveLayer
        self.position = position
        self.size = size
        self.parentSize = parentSize
        self.document = document

        super.init()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    // Trackpad-based gestures
    @objc func trackpadPanInView(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
        let location = gestureRecognizer.location(in: gestureRecognizer.view)

        //        log("PreviewElementTrackpadDelegate: trackpadPanInView")

        let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)

        //        log("PreviewElementTrackpadDelegate: trackpadPanInView: gestureRecognizer.state.description:  \(gestureRecognizer.state.description)")

        switch gestureRecognizer.state {

        case .began, .changed:
            //            log("PreviewElementTrackpadDelegate: trackpadPanInView: .began, .changed")

            // TODO: would be better to retrieve childSize and childPosition for this layer at this index etc. in the event handler itself?
            document?.layerDragged(
                interactiveLayer: interactiveLayer,
                location: location,
                translation: translation.toCGSize,
                velocity: velocity.toCGSize,
                parentSize: parentSize,
                childSize: size,
                childPosition: position)

        case .ended, .cancelled:
            //            log("PreviewElementTrackpadDelegate: trackpadPanInView: .ended, .cancelled")
            document?.layerDragEnded(
                interactiveLayer: interactiveLayer,
                parentSize: parentSize,
                childSize: size)
        default:
            break
        }
    }
}

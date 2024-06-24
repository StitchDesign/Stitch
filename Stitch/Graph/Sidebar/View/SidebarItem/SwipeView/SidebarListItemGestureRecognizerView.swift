//
//  _SidebarListItemGestureRecognizerView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import Foundation
import SwiftUI
import UIKit

// CGFloat: height if for item-drag; width if for item-swipe
typealias OnDragChangedHandler = (CGFloat) -> Void
typealias OnDragChangedWithVelocityHandler = (CGFloat, CGPoint) -> Void

typealias OnDragEndedHandler = () -> Void

// dragging an item is both vertical and horizontal,
// so need to pass in CGSize
typealias OnItemDragChangedHandler = (CGSize) -> Void

// Gesture Recognizer attached to the Item itself,
// to detect trackpad 2-finger pans (for swipe)
// or trackpad click + drag (for immediate item dragging)

// a gesture recognizer for the item in the custom list itself
struct SidebarListItemGestureRecognizerView<T: View>: UIViewControllerRepresentable {
    let view: T
    @ObservedObject var gestureViewModel: SidebarItemGestureViewModel

    var instantDrag: Bool = false

    func makeUIViewController(context: Context) -> GestureHostingController<T> {
        let vc = GestureHostingController(
            rootView: view,
            ignoresSafeArea: false,
            ignoreKeyCommands: true,
            name: "SidebarListItemGestureRecognizerView")

        let delegate = context.coordinator

        let screenTouch = NSNumber(value: UITouch.TouchType.direct.rawValue)
        let trackpadTouch = NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)

        let screenPanGesture = UIPanGestureRecognizer(
            target: delegate,
            action: #selector(delegate.screenGestureHandler))
        screenPanGesture.allowedScrollTypesMask = [.continuous, .discrete]
        // uses screen; ignore trackpad
        screenPanGesture.allowedTouchTypes = [screenTouch]
        screenPanGesture.delegate = delegate
        vc.view.addGestureRecognizer(screenPanGesture)

        let trackpadPanGesture = UIPanGestureRecognizer(
            target: delegate,
            action: #selector(delegate.trackpadGestureHandler))
        trackpadPanGesture.allowedScrollTypesMask = [.continuous, .discrete]
        // ignore screen; uses trackpad
        trackpadPanGesture.allowedTouchTypes = [trackpadTouch]
        trackpadPanGesture.delegate = delegate
        vc.view.addGestureRecognizer(trackpadPanGesture)

        vc.delegate = delegate
        return vc
    }

    func updateUIViewController(_ uiViewController: GestureHostingController<T>, context: Context) {
        let delegate = context.coordinator
        uiViewController.rootView = view

        delegate.instantDrag = instantDrag
    }

    func makeCoordinator() -> SidebarListGestureRecognizer {
        SidebarListGestureRecognizer(
            gestureViewModel: gestureViewModel,
            instantDrag: instantDrag)
    }
}

final class SidebarListGestureRecognizer: NSObject, UIGestureRecognizerDelegate {
    // Handles:
    // - one finger on screen item-swiping
    // - two fingers on trackpad item-swiping
    // - click on trackpad item-dragging

    // Handled elsewhere:
    // - one finger long-press-drag item-dragging: see `SwiftUI .simultaneousGesture`
    // - two fingers on trackpad list scrolling

    let gestureViewModel: SidebarItemGestureViewModel

    var instantDrag: Bool

    init(gestureViewModel: SidebarItemGestureViewModel,
         instantDrag: Bool) {
        self.gestureViewModel = gestureViewModel
        self.instantDrag = instantDrag
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    // finger on screen
    @objc func screenGestureHandler(_ gestureRecognizer: UIPanGestureRecognizer) {

        // for finger on screen, we'll still use long press + drag for item-dragging;
        // so we'll still use a SwiftUI long-press-drag gesture
        // (unless we accidentally trigger both, via trackpad?)

        let translation = gestureRecognizer.translation(in: gestureRecognizer.view)

        // one finger on screen: can be item-drag or item-swipe;
        // since SwiftUI was doing both via simultaneous gestures,
        // just call both handlers here

        if gestureRecognizer.numberOfTouches == 1 {
            switch gestureRecognizer.state {
            case .changed:

                if instantDrag {
                    gestureViewModel.onItemDragChanged(translation.toCGSize)
                }
                let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)
                gestureViewModel.onItemSwipeChanged(translation.x)
            default:
                break // do nothing
            }
        }

        // When the finger-on-the-screen gesture is ended or cancelled, touches=0
        else if gestureRecognizer.numberOfTouches == 0 {
            //            log("CustomListItemGestureRecognizerVC: screenGestureHandler: 0 touches ")
            switch gestureRecognizer.state {
            case .ended, .cancelled:
                if instantDrag {
                    gestureViewModel.onItemDragEnded()
                }
                gestureViewModel.onItemSwipeEnded()
            default:
                break
            }
        }
        //        else {
        //            log("CustomListItemGestureRecognizerVC: screenGestureHandler: incorrect number of touches; will do nothing")
        //        }

    } // screenGestureHandler

    @objc func trackpadGestureHandler(_ gestureRecognizer: UIPanGestureRecognizer) {

        //        log("CustomListItemGestureRecognizerVC: trackpadGestureHandler: gestureRecognizer.numberOfTouches:  \(gestureRecognizer.numberOfTouches)")

        let translation = gestureRecognizer.translation(in: gestureRecognizer.view)

        // when we have clicked+dragged, and then let up our finger,
        // is that a touches=0 gesture?

        // `touches == 0` = running our fingers on trackpad, but no click
        if gestureRecognizer.numberOfTouches == 0 {
            switch gestureRecognizer.state {
            case .changed:
                gestureViewModel.onItemSwipeChanged(translation.x)
                let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view)
            case .ended, .cancelled:
                gestureViewModel.onItemSwipeEnded()
                gestureViewModel.onItemDragEnded()
            default:
//                log("CustomListItemGestureRecognizerVC: touches 0: trackpadGestureHandler: default")
                break
            }
        }

        // `touches == 1` = click + drag
        else if gestureRecognizer.numberOfTouches == 1 {
            switch gestureRecognizer.state {
            case .changed:
                gestureViewModel.onItemDragChanged(translation.toCGSize)
            default:
                // log("CustomListItemGestureRecognizerVC: trackpadGestureHandler: default")
                break
            }
        }
    } // trackpadGestureHandler
}

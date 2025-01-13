//
//  FullScreenGestureRecognizerView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/26/22.
//

import SwiftUI
import UIKit

struct FullScreenGestureRecognizerView<Content: View>: UIViewControllerRepresentable {

    let showFullScreenPreviewSheet: Bool
    @ViewBuilder var content: () -> Content

    func makeUIViewController(context: Context) -> GestureHostingController<Content> {
        // Ignore safe area on Catalyst
        #if targetEnvironment(macCatalyst)
        let ignoresSafeArea = true
        #else
        let ignoresSafeArea = false
        #endif

        let delegate = context.coordinator
        let vc = GestureHostingController(
            rootView: content(),
            ignoresSafeArea: ignoresSafeArea,
            ignoreKeyCommands: true,
            inputTextFieldFocused: false, // N/A
            name: .fullScreenGestureRecognzer)
        vc.delegate = delegate

        // three-finger tap gesture opens action sheet
        let threeFingerTapGesture =
            UITapGestureRecognizer(target: delegate,
                                   action: #selector(delegate.threeFingerTapInView))

        // three-finger double tap gesture closes graph
        let threeFingerDoubleTapGesture =
            UITapGestureRecognizer(target: delegate,
                                   action: #selector(delegate.threeFingerDoubleTapInView))

        threeFingerTapGesture.numberOfTouchesRequired = 3
        threeFingerDoubleTapGesture.numberOfTouchesRequired = 3
        threeFingerDoubleTapGesture.numberOfTapsRequired = 2

        // Necessary to enable double-tap gesture, otherwise it's never recognized
        threeFingerTapGesture.require(toFail: threeFingerDoubleTapGesture)

        threeFingerTapGesture.delegate = delegate
        threeFingerDoubleTapGesture.delegate = delegate

        vc.view.addGestureRecognizer(threeFingerTapGesture)
        vc.view.addGestureRecognizer(threeFingerDoubleTapGesture)
        vc.view.isUserInteractionEnabled = true
        return vc
    }

    func updateUIViewController(_ uiViewController: GestureHostingController<Content>,
                                context: Context) {
        uiViewController.rootView = content()
    }

    func makeCoordinator() -> FullScreenGestureCoordinator {
        FullScreenGestureCoordinator()
    }
}

// Enables simultaneous gestures with SwiftUI gesture handlers
class FullScreenGestureCoordinator: NSObject, UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    @objc func threeFingerTapInView(_ gestureRecognizer: UITapGestureRecognizer) {
        dispatch(ToggleFullScreenPreviewSheet())
    }

    @objc func threeFingerDoubleTapInView(_ gestureRecognizer: UITapGestureRecognizer) {
        if isPhoneDevice() {
            // iPhone never persists a project
            dispatch(CloseGraph())
        } else {
            dispatch(ToggleFullScreenEvent())
        }
    }
}

// struct FullScreenGestureRecognizerView_Previews: PreviewProvider {
//    static var previews: some View {
//        FullScreenGestureRecognizerView()
//    }
// }

//
//  StitchButton.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/15/22.
//

import SwiftUI
import StitchSchemaKit

// Overrides for the SwiftUI button to ensure button styling
// is borderless by default (which is an issue on Catalyst).
struct StitchButton<Label>: View where Label: View {
    let action: @MainActor () -> Void
    var role: ButtonRole?
    @ViewBuilder var label: () -> Label

    init(action: @Sendable @MainActor @escaping () -> Void,
         @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        if let role = role {
            Button(role: role,
                   action: action,
                   label: label)
                .stitchButton
        } else {
            Button(action: action,
                   label: label)
                .stitchButton
        }
    }
}

struct StitchButtonViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderless)
            .foregroundColor(Color(.titleFont))
    }
}

extension View {
    var stitchButton: some View {
        self.modifier(StitchButtonViewModifier())
    }
}

extension StitchButton where Label == Text {
    init(_ titleKey: String,
         action: @MainActor @escaping () -> Void) {
        self.action = action
        self.label = {
            Text(titleKey)
                .font(STITCH_FONT)
        }
    }

    init(_ titleKey: String, role: ButtonRole?,
         action: @MainActor @escaping () -> Void) {
        self.action = action
        self.role = role
        self.label = {
            Text(titleKey)
        }
    }

}

extension StitchButton {
    init(role: ButtonRole?,
         action: @MainActor @escaping () -> Void,
         @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
        self.role = role
    }
}

/// Provides a `UIViewControllerRepesentable` version of a "button", which is useful for views
/// which may need UIKit to have gesture events be registered.
struct UIKitTappableWrapper<T: View>: UIViewControllerRepresentable {
    let tapCallback: () -> Void
    @ViewBuilder var view: () -> T

    func makeUIViewController(context: Context) -> GestureHostingController<T> {
        let vc = GestureHostingController(
            rootView: view(),
            ignoresSafeArea: false,
            ignoreKeyCommands: true,
            inputTextFieldFocused: false, // N/A
            name: .uiKitTappableWrapper)
        let delegate = context.coordinator

        let tapGesture = UITapGestureRecognizer(target: delegate,
                                                action: #selector(delegate.tapGestureHandler))
        tapGesture.delegate = delegate
        vc.view.addGestureRecognizer(tapGesture)

        // So that uikit-tappable wrapper does not affect colors of view on which it is applied;
        // helpful for `CatalystNavBarButton`
        vc.view.backgroundColor = .clear

        vc.delegate = delegate
        return vc
    }

    func updateUIViewController(_ uiViewController: GestureHostingController<T>, context: Context) {
        uiViewController.rootView = view()
        context.coordinator.tapCallback = tapCallback
    }

    func makeCoordinator() -> UIKitTappableWrapperDelegate {
        UIKitTappableWrapperDelegate(tapCallback: tapCallback)
    }
}

final class UIKitTappableWrapperDelegate: NSObject, UIGestureRecognizerDelegate {
    var tapCallback: () -> Void

    init(tapCallback: @escaping () -> Void) {
        self.tapCallback = tapCallback
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        // NOT NEEDED?
        if otherGestureRecognizer is UILongPressGestureRecognizer {
            //            log("UIKitTappableWrapperDelegate: will disable long press gesture")
            otherGestureRecognizer.disableTemporarily()
        }

        return true
    }

    @objc func tapGestureHandler(_ gestureRecognizer: UITapGestureRecognizer) {
        //        log("UIKitTappableWrapperDelegate: tapGestureHandler")
        self.tapCallback()
    }
}

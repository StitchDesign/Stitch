//
//  UIKitWrapper.swift
//  Stitch
//
//  Created by Nicholas Arner on 6/9/22.
//

import UIKit
import SwiftUI
import StitchSchemaKit

// https://developer.apple.com/documentation/uikit/uiview/1622415-clipstobounds
// a SwiftUI view that accepts another SwiftUI view T, and which wraps T in a UIKit view
struct UIKitWrapper<T: View>: UIViewControllerRepresentable {
    let ignoresKeyCommands: Bool
    let name: KeyListenerName
    @ViewBuilder var content: () -> T

    // called when first made
    func makeUIViewController(context: Context) -> StitchHostingController<T> {

        // UIKitWrapper wraps our floating preview window,
        // which needs to ignore the keyboard.
        return StitchHostingController<T>(
            rootView: content(),
            ignoresSafeArea: true,
            ignoreKeyCommands: ignoresKeyCommands,
            name: name)
    }

    // called on updates
    func updateUIViewController(_ uiViewController: StitchHostingController<T>,
                                context: Context) {
        uiViewController.rootView = content()
    }
}

// https://steipete.com/posts/disabling-keyboard-avoidance-in-swiftui-uihostingcontroller/

// https://gist.github.com/steipete/da72299613dcc91e8d729e48b4bb582c#file-uihostingcontroller-keyboard-swift

extension UIHostingController {
    /// Resolves issue where `UIHostingController` will fail to ignore safe areas. Fixes an issue in Stitch where
    /// the full screen preview may render above the iPad's home indicator.
    func disableSafeArea() {
        //        log("UIHostingController: extension: disableSafeArea")
        guard let viewClass = object_getClass(view) else { return }

        let viewSubclassName = String(cString: class_getName(viewClass)).appending("_IgnoreSafeArea")
        if let viewSubclass = NSClassFromString(viewSubclassName) {
            object_setClass(view, viewSubclass)
        } else {
            guard let viewClassNameUtf8 = (viewSubclassName as NSString).utf8String else { return }
            guard let viewSubclass = objc_allocateClassPair(viewClass, viewClassNameUtf8, 0) else { return }

            if let method = class_getInstanceMethod(UIView.self, #selector(getter: UIView.safeAreaInsets)) {
                let safeAreaInsets: @convention(block) (AnyObject) -> UIEdgeInsets = { _ in
                    return .zero
                }
                class_addMethod(viewSubclass, #selector(getter: UIView.safeAreaInsets), imp_implementationWithBlock(safeAreaInsets), method_getTypeEncoding(method))
            }

            if let method2 = class_getInstanceMethod(viewClass, NSSelectorFromString("keyboardWillShowWithNotification:")) {
                let keyboardWillShow: @convention(block) (AnyObject, AnyObject) -> Void = { _, _ in }
                class_addMethod(viewSubclass, NSSelectorFromString("keyboardWillShowWithNotification:"), imp_implementationWithBlock(keyboardWillShow), method_getTypeEncoding(method2))
            }

            objc_registerClassPair(viewSubclass)
            object_setClass(view, viewSubclass)
        }
    }
}

//
//  UIKitExtensionUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension UISplitViewController.Style: CustomStringConvertible {
    public var description: String {
        switch self {
        case .doubleColumn:
            return ".doubleColumn"
        case .tripleColumn:
            return ".tripleColumn"
        case .unspecified:
            return ".unspecified"
        default:
            return "default"
        }
    }

}

extension UIGestureRecognizer {
    /// Temporarily disables a gesture. Used predominantly in our gesture delegate classes within view controllers.
    func disableTemporarily() {
        self.isEnabled = false
        self.isEnabled = true
    }
}

extension UIGestureRecognizer.State: CustomStringConvertible {
    public var description: String {
        switch self {
        case .began:
            return ".began"
        case .cancelled:
            return ".cancelled"
        case .changed:
            return ".changed"
        case .ended:
            return ".ended"
        case .failed:
            return ".failed"
        case .possible:
            return ".possible"
        case .recognized:
            return ".recognized"
        default:
            return "default"
        }
    }
}

extension UIHostingController {
    // Used by our UIHostingControllers to make UIView's full screen
    func setupFullscreenConstraints(ignoresSafeArea: Bool) {
        // VERY important hack to get full screen to ignore indicator
        if ignoresSafeArea {
            self.disableSafeArea()
        }

        // MARK: this causes layout warnings due to ambiguous positioning to view
        self.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        self.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        self.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        self.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        self.didMove(toParent: self)
    }
}

extension UIApplication {
    /// Fixes bug where keyboard may not disappear on background selections in views.
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

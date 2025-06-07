//
//  CatalystNavbarToolTipView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/6/25.
//

import SwiftUI
import UIKit

/// A UIViewRepresentable that wraps a UIButton and installs a macOS‐style tooltip.
struct CatalystToolbarButton: UIViewRepresentable {
    /// The SF Symbol name (or custom image name) for the button’s icon
    let systemImageName: String
    /// The text you want to appear as the tooltip when hovering
    let tooltipText: String
    /// The closure to invoke when the user taps/activates the button
    let action: () -> Void

    func makeUIView(context: Context) -> UIButton {
        // 1) Create a plain system‐style UIButton
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        // 2) Set its image using a bold-weight SF Symbol (default size) for a darker look
        let config = UIImage.SymbolConfiguration(weight: .unspecified)
        let image = UIImage(systemName: systemImageName, withConfiguration: config)
        button.setImage(image, for: .normal)

        // 3) Wire up the action
        button.addTarget(context.coordinator,
                         action: #selector(Coordinator.performAction),
                         for: .touchUpInside)

        // 4) Install a macOS‐style tooltip (iOS-15+ / macCatalyst‐14+)
        if #available(iOS 15.0, *) {
            let interaction = UIToolTipInteraction(defaultToolTip: tooltipText)
            button.addInteraction(interaction)
        }

        // Install pointer interaction for pointer highlighting (iOS 13.4+)
        if #available(iOS 13.4, *) {
            let pointerInteraction = UIPointerInteraction(delegate: context.coordinator)
            button.addInteraction(pointerInteraction)
        }

        // Ensure minimum hit area for tooltip (30×30)
//        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
//        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        
        // Increase tappable area around symbol
        button.contentEdgeInsets = UIEdgeInsets(top: 7, left: 7, bottom: 7, right: 7)

        // Ensure minimum hit area for tooltip (44×44)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true


        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        // Update image if the symbol name changed
        let config = UIImage.SymbolConfiguration(weight: .unspecified)
        if let image = UIImage(systemName: systemImageName, withConfiguration: config) {
            uiView.setImage(image, for: .normal)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject, UIPointerInteractionDelegate {
        let action: () -> Void
        init(action: @escaping () -> Void) {
            self.action = action
        }
        @objc func performAction() {
            action()
        }
        @available(iOS 13.4, *)
        func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
            guard let buttonView = interaction.view else { return nil }
            let preview = UITargetedPreview(view: buttonView)
            let effect = UIPointerEffect.highlight(preview)
            return UIPointerStyle(effect: effect, shape: nil)
        }
    }
}

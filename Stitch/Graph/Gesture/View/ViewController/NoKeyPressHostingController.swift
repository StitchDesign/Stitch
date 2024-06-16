//
//  NoKeyPressHostingController.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/24/23.
//

import SwiftUI
import StitchSchemaKit

/// Used by various SwiftUI views to inject a view into a view controller
class NoKeyPressHostingController<T: View>: UIHostingController<T> {
    let ignoresSafeArea: Bool
    let name: String

    init(rootView: T,
         ignoresSafeArea: Bool,
         ignoreKeyCommands: Bool,
         name: String) {
        self.ignoresSafeArea = ignoresSafeArea
        self.name = name
        super.init(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupFullscreenConstraints(ignoresSafeArea: self.ignoresSafeArea)

        self.view.backgroundColor = .clear
    }
}

// A very simple view implementation of a `StitchHostingController`.
struct NoKeyPressHostingControllerView<T: View>: View {
    let ignoreKeyCommands: Bool
    let name: String
    @ViewBuilder var view: () -> T

    var body: some View {
        NoKeyPressHostingControllerViewRepresentable(
            view: view(),
            ignoreKeyCommands: ignoreKeyCommands,
            name: name)
    }
}

/// A very simple view implementation of a `StitchHostingController`.
struct NoKeyPressHostingControllerViewRepresentable<T: View>: UIViewControllerRepresentable {
    let view: T
    let ignoreKeyCommands: Bool
    let name: String

    func makeUIViewController(context: Context) -> NoKeyPressHostingController<T> {
        NoKeyPressHostingController(rootView: view,
                                    ignoresSafeArea: false,
                                    ignoreKeyCommands: ignoreKeyCommands,
                                    name: name)
    }

    func updateUIViewController(_ uiViewController: NoKeyPressHostingController<T>, context: Context) {
        uiViewController.rootView = view
    }
}

//
//  VisualEffectView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI

struct VisualEffectView: UIViewRepresentable {

    var effect: UIVisualEffect?

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        UIVisualEffectView()
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}

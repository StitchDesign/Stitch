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
        let view = UIVisualEffectView()
        view.effect = effect
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView,
                      context: UIViewRepresentableContext<Self>) {
        // Note: does not actually update the current effect?
        uiView.effect = effect

        // Note: Stops working after a couple changes? Or does not take into account .dark vs .light changes
        // See also:
        // - https://www.hackingwithswift.com/example-code/uikit/how-to-animate-a-blur-effect-using-uivisualeffectview
        //        uiView.effect = nil
        //        UIView.animate(withDuration: 0.1, animations: {
        //            uiView.effect = effect
        //        })
    }
}

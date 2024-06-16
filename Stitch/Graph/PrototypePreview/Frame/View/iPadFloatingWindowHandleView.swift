//
//  iPadFloatingWindowHandleView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/16/24.
//

import SwiftUI
import UIKit

struct iPadFloatingWindowHandleView: View {
    var body: some View {
        iPadFloatingHandle()
        #if DEV_DEBUG
        .border(.red, width: 2)
        #endif
    }
}

struct iPadFloatingHandle: UIViewRepresentable {
    func makeUIView(context: Context) -> some UIView {
        // log("iPadFloatingHandle: makeUIView")
        let button = UIButton()
        button.backgroundColor = .clear // so can't be seen
        button.pointerStyleProvider = buttonProvider
        return button
    }

    func updateUIView(_ uiView: UIViewType,
                      context: Context) {
        // log("iPadFloatingHandle: updateUIView")
    }

    @MainActor
    func buttonProvider(button: UIButton,
                        pointerEffect: UIPointerEffect,
                        pointerShape: UIPointerShape) -> UIPointerStyle? {
        // log("iPadFloatingHandle: buttonProvider")
        return UIPointerStyle(shape: UIPointerShape.path(.resizeIcon))
    }
}

extension UIBezierPath {
    static var resizeIcon: UIBezierPath {
        let side = 16.0
        let path = UIBezierPath()

        // NE-facing triangle

        // Start in top right corner
        path.move(to: CGPoint(x: side, y: .zero))

        path.addLine(to: CGPoint(x: (side * 0.75),
                                 y: (side * 0.75)))

        path.addLine(to: CGPoint(x: (side * 0.25),
                                 y: (side * 0.25)))

        path.close()

        // the distance separating the two triangles
        let gap = side/2

        // SW-facing triangle

        // Start in bottom left corner
        path.move(to: CGPoint(x: .zero - gap,
                              y: side + gap))

        path.addLine(to: CGPoint(x: (side * 0.25) - gap,
                                 y: (side * 0.25) + gap))

        path.addLine(to: CGPoint(x: (side * 0.75) - gap,
                                 y: (side * 0.75)  + gap))

        path.close()

        return path
    }

}

#Preview {
    iPadFloatingWindowHandleView()
}

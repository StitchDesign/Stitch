//
//  CursorDotView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/6/21.
//

import SwiftUI
import StitchSchemaKit

let LARGE_CURSOR_LENGTH: CGFloat = 80
let SMALL_CURSOR_LENGTH = LARGE_CURSOR_LENGTH / 3

struct CursorDotView: View {

    @Environment(\.appTheme) var theme

    let currentDragLocation: CGPoint
    let isFingerOnScreenSelection: Bool
    let scale: CGFloat

    @State var length: CGFloat = 0

    var body: some View {
        Circle()
            .fill(theme.themeData.edgeColor)
            .frame(width: length * 1/scale,
                   height: length * 1/scale)
            .position(currentDragLocation)
            .onAppear {
                let finalSize = isFingerOnScreenSelection ? LARGE_CURSOR_LENGTH : SMALL_CURSOR_LENGTH
                let animationTime = isFingerOnScreenSelection ? 0.25 : 0.1
                withAnimation(.easeIn(duration: animationTime)) {
                    length = finalSize
                }
            }
    }
}

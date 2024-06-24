//
//  AutoEdgeInputTagView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/24.
//

import SwiftUI

struct EdgeEditModeInputLabelView: View {

    let label: EdgeEditingModeInputLabel
    let isPressed: Bool

    static let nonPressOpacity = 0.0
    static let pressOpacity = 0.3
    @State var overlayOpacity: Double = Self.nonPressOpacity

    var body: some View {
        Button {
            log("EdgeEditModeInputLabel tapped")
        } label: {
            StitchTextView(string: label.display)
        }
        .onChange(of: self.isPressed) { _, _ in
            // Note: `withAnimation` breaks other ongoing animations for the possible edges?!
            // withAnimation(.linear(duration: 0.1)) { toggleOverlayOpacity() }
            toggleOverlayOpacity()
        }
        // // NOTE: .bordered and .borderedProminent break key presses (Catalyst only)
        // .buttonStyle(.bordered)
        // .buttonStyle(.borderedProminent)
        .frame(width: 18, height: 18)
        .buttonStyle(.borderless)
        .background(NodeUIColor.patchNode.title)
        .tint(STITCH_TITLE_FONT_COLOR)
        .overlay {
            STITCH_TITLE_FONT_COLOR // // black in light mode, white in dark mode
                .opacity(self.overlayOpacity)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .offset(x: -32)

        // Note: our other key press listening logic seems to block .keyboardShortcut
        //        .keyboardShortcut(KeyEquivalent(labelAsChar), modifiers: [])
        //        .keyboardShortcut("a", modifiers: [])
    }

    func toggleOverlayOpacity() {
        self.overlayOpacity = self.overlayOpacity == Self.nonPressOpacity ? Self.pressOpacity : Self.nonPressOpacity
    }
}

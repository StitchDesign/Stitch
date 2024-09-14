//
//  PulseValueButton.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/7/22.
//

import SwiftUI
import StitchSchemaKit

let PULSE_ICON_SF_SYMBOL_NAME = "record.circle.fill"

struct PulseValueButtonView: View {
    @State private var isPulsed = false
    
    let inputCoordinate: NodeIOCoordinate? // nil = for output
    
    let nodeId: NodeId
    let pulseTime: TimeInterval

    // always false for outputs
    let hasIncomingEdge: Bool

    var pulseColor: PulseColor {
        isPulsed ? .active : .inactive
    }

    /*
     NOTE: Do not use StitchButton here; clickable image is enough.

     Using StitchButton with the .overlay(NodeInteractiveView)
     means we can drag and press the button at the same time,
     which is not behavior that we want.
     */
    var body: some View {
        // TODO: you made this a button, double check it works
        StitchButton {
            if let inputCoordinate = inputCoordinate {
                dispatch(PulseValueButtonClicked(coordinate: inputCoordinate))
            } else {
                log("PulseValueButtonView error: output unexpectedly encountered for \(nodeId)")
            }
        } label: {
            Image(systemName: PULSE_ICON_SF_SYMBOL_NAME)
                .foregroundColor(pulseColor.color)
            // This animation causes the bug described here: https://github.com/vpl-codesign/stitch/issues/2387
            // .animation(.linear(duration: 0.25), value: color.color)
        }
        .disabled(hasIncomingEdge || !inputCoordinate.isDefined)
        // Check if we should visibily pulse node as new pulse data comes in
        .onChange(of: pulseTime) {
            // Note: `isPulsed` in this UI is different from our `shouldPulse` check in nodes' evals
            self.isPulsed = true
        }
        .task(id: pulseTime) {
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run {
                self.isPulsed = false
            }
        }
    }
}

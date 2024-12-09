//
//  NativeScrollInteraction.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/3/24.
//

import SwiftUI

// Not needed anymore?
//struct _NativeScrollInteractionNode: PatchNodeDefinition {
struct NativeScrollInteractionNode {
//    static let layer = Patch.nativeScrollInteraction
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [interactionIdDefault],
                    label: "Layer"
                ),
                .init(
                    defaultValues: [.bool(Self.defaultScrollXEnabled)],
                    label: "Scroll X Enabled"
                ),
                .init(
                    defaultValues: [.bool(Self.defaultScrollYEnabled)],
                    label: "Scroll Y Enabled"
                ),
                .init(
                    defaultValues: [.size(.zero)],
                    label: "Content Size"
                ),
                .init(
                    defaultValues: [.scrollJumpStyle(.scrollJumpStyleDefault)],
                    label: "Jump Style X"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Jump to X"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Jump Position X"
                ),
                .init(
                    defaultValues: [.scrollJumpStyle(.scrollJumpStyleDefault)],
                    label: "Jump Style Y"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Jump to Y"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Jump Position Y"
                )
            ],
            outputs: [
                .init(
                    label: LayerInputPort.position.label(),
                    type: .position
                )
            ]
        )
    }

    static let defaultScrollXEnabled: Bool = false
    static let defaultScrollYEnabled: Bool = false
    
    static let defaultIndicatorsHidden: Bool = true
    
    static let defaultOutputs: PortValuesList =  [[.position(.zero)]]
}



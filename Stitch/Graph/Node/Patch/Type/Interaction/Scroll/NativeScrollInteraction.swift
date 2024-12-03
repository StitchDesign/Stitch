//
//  NativeScrollInteraction.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/3/24.
//

import SwiftUI

struct NativeScrollInteractionNode: PatchNodeDefinition {
    static let patch = Patch.nativeScrollInteraction
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [interactionIdDefault],
                    label: "Layer"
                ),
                .init(
                    defaultValues: [scrollModeDefault],
                    label: "Scroll X"
                ),
                .init(
                    defaultValues: [scrollModeDefault],
                    label: "Scroll Y"
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

    // NOT NEEDED
//    static func createEphemeralObserver() -> NodeEphemeralObservable? {
//        ScrollInteractionState()
//    }
    
}


/*
 Inputs are extended to be as long as the longest loop on the *assigned layer*
 
 Eval modifies underlying layer view models.
 
 ?? When ScrollView.onScrollGeometry fires, we update the LayerViewModel's InteractiveLayer, then call the nativeScrollInteractionEval.
 */
@MainActor
func nativeScrollInteractionEval(node: PatchNode,
                                 // should be impure?
//                                 state: GraphDelegate) -> EvalResult {
                                 state: GraphDelegate) {
    
//    return .init()
    
}

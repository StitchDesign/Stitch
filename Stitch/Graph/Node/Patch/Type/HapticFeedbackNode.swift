//
//  HapticFeedbackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/14/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct HapticFeedbackNode: PatchNodeDefinition {
    static let patch = Patch.hapticFeedback

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Play"
                ),
                .init(
                    defaultValues: [.mobileHapticStyle(.heavy)],
                    label: "Style"
                ),
            ],
            outputs: [
                .init(
                    label: "",
                    type: .number
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        ComputedNodeState()
    }
}

@MainActor
func hapticFeedbackEval(node: PatchNode,
                        graphStep: GraphStepState) -> ImpureEvalResult {

    let inputsValues = node.inputs
    let outputsValues = node.outputs
    let graphTime: TimeInterval = graphStep.graphTime

    let previousOutput: PortValues = outputsValues.first ?? [.number(.zero)]

    let op = hapticFeedbackOpClosure(graphTime: graphTime)

    return pulseEvalUpdate(
        inputsValues,
        [previousOutput],
        op)
}

@MainActor
func hapticFeedbackOpClosure(graphTime: TimeInterval) -> PulseOperationT {

    return { (values: PortValues) -> PulseOpResultT in
        
        let playPulsed = (values[safe: 0]?.getPulse ?? .zero).shouldPulse(graphTime)

        // old output; never changed
        let prevValue = values[safe: 1] ?? .number(.zero)
        
        let style = values[safe: 1]?.getMobileHapticStyle?.toUIImapactFeedbackGenerator
        if playPulsed {
            // TODO: should return as genuine side-effect
            doImpactHapticFeedback(feedbackStyle: style ?? .heavy)
        }

        return PulseOpResultT(prevValue)
    }
}

// side-effect
@MainActor
func doImpactHapticFeedback(feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle,
                            // between 0 and 1
                            intensity: Double = 1) {

    let generator = UIImpactFeedbackGenerator(style: feedbackStyle)

    // does the actual haptic rumble
    generator.impactOccurred(intensity: intensity)
}


extension MobileHapticStyle: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<MobileHapticStyle> {
        PortValue.mobileHapticStyle
    }
}

extension PortValue {
    // Takes any PortValue, and returns a MobileHapticStyle
    func coerceToMobileHapticStyle() -> MobileHapticStyle {
        switch self {
        case .mobileHapticStyle(let x):
            return x
        case .number(let x):
            return MobileHapticStyle.fromNumber(x).getMobileHapticStyle ?? .heavy
        default:
            return .heavy
        }
    }
}

func mobileHapticStyleCoercer(_ values: PortValues) -> PortValues {
    values
        .map { $0.coerceToMobileHapticStyle() }
        .map(PortValue.mobileHapticStyle)
}

extension MobileHapticStyle {
    static let defaultMobileHapticStyle: MobileHapticStyle = .heavy

    var toUIImapactFeedbackGenerator: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light:
            return .light
        case .medium:
            return .medium
        case .heavy:
            return .heavy
        }
    }

}

//
//  SplitterPatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

//        let min = 188.0 // not enough
//        let min = 192.0 // too much ?
let SPLITTER_NODE_MINIMUM_WIDTH: CGFloat = 190

// Starts out as a number?
struct SplitterPatchNode: PatchNodeDefinition {
    static let patch = Patch.splitter

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: type ?? .number
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

@MainActor
func splitterEval(node: PatchNode,
                  graphStep: GraphStepState) -> EvalResult {

    // a Splitter patch must have a node-type
    assertInDebug(node.userVisibleType.isDefined)

    if node.userVisibleType == .pulse || node.userVisibleType == .media {
        
        // TODO: debug why this broke the Monthly Stays demo: https://github.com/StitchDesign/Stitch--Old/issues/7049
        return node.loopedEval { (values, loopIndex) -> MediaEvalOpResult in
            // splitter must have node-type
            guard let nodeType = node.userVisibleType else {
                fatalErrorIfDebug()
                return MediaEvalOpResult(values: [.number(.zero)])
            }
            
            let value: PortValue = values[0]
            
            let pulsed = (value.getPulse ?? .zero).shouldPulse(graphStep.graphTime)
            if nodeType == .pulse {
                if pulsed {
                    return MediaEvalOpResult(values: [.pulse(graphStep.graphTime)])
                }
            }
            
            if nodeType == .media,
               let media = node.getInputMedia(portIndex: 0,
                                              loopIndex: loopIndex,
                                              mediaId: nil) {
                return MediaEvalOpResult(values: [value],
                                         media: .init(computedMedia: media))
            }
            
            return MediaEvalOpResult(values: [value])
        }
        .createPureEvalResult(node: node)
        
    } else {
        return .init(outputsValues: node.inputs)
    }
}

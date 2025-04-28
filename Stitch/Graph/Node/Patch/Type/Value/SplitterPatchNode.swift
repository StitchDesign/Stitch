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
func mediaAwareIdentityEvaluation(node: PatchNode) -> EvalResult {
    
    if node.userVisibleType == .media {
        // TODO: debug why this broke the Monthly Stays demo: https://github.com/StitchDesign/Stitch--Old/issues/7049
        return node.getLoopedEvalResults { (values, loopIndex) -> MediaEvalOpResult in
            // splitter must have node-type
            guard let nodeType = node.userVisibleType else {
                fatalErrorIfDebug()
                return MediaEvalOpResult(values: [.number(.zero)])
            }
            
            let value: PortValue = values[0]
            if nodeType == .media,
               let media = node.getInputMedia(portIndex: 0,
                                              loopIndex: loopIndex,
                                              mediaId: nil) {
                return MediaEvalOpResult(values: [value],
                                         media: .init(computedMedia: media,
                                                      id: value.asyncMedia?.id ?? .init()))
            }
            
            return MediaEvalOpResult(values: [value],
                                     media: nil)
        }
        .createPureEvalResult(node: node)
        
    } else {
        return .init(outputsValues: node.inputs)
    }
}

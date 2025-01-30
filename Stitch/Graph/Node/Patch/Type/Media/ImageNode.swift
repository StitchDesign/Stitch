//
//  ImageNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/3/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct ImageImportPatchNode: PatchNodeDefinition {
    static let patch = Patch.imageImport

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.asyncMedia(nil)],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    type: .media
                ),
                .init(
                    type: .size
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

@MainActor
func imageImportEval(node: PatchNode) -> EvalResult {
    node.loopedEval(MediaEvalOpObserver.self) { values, asyncObserver, loopIndex in
        let prevValues = values.prevOutputs(node: node)
    
        return asyncObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                              values: values,
                                              node: node) { [weak asyncObserver] in
            guard let media = await asyncObserver?.getUniqueMedia(inputPortIndex: 0,
                                                                  loopIndex: loopIndex),
                  let image = media.mediaObject.image else {
//                let isLoading = asyncObserver.currentLoadingMediaId != nil
                
//                if isLoading {
//                    // Return previous values if loading
//                    return values.prevOutputs(node: node)
//                } else {
//                    // Else there's no image to which we return default outputs
                    return [.asyncMedia(nil), .size(.zero)]
//                }
            }
            
            return [media.portValue, .size(image.layerSize)]
        }
    }
}

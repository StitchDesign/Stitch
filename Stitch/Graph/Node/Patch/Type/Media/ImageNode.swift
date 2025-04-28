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
        asyncObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                       values: values,
                                       node: node) { [weak asyncObserver] () -> MediaEvalOpResult in
            guard let mediaValue = values.first?.asyncMedia,
                  let media = await asyncObserver?.getUniqueMedia(inputMediaValue: mediaValue,
                                                                  inputPortIndex: 0,
                                                                  loopIndex: loopIndex),
                  let image = media.mediaObject.image else {
                return .init(from: [.asyncMedia(nil), .size(.zero)])
            }
            
            let computedMediaValue = AsyncMediaValue(id: media.id,
                                                     dataType: .computed,
                                                     label: mediaValue.label)
            return .init(values: [
                .asyncMedia(computedMediaValue),
                .size(image.layerSize)
            ], media: media)
        }
    }
}

//
//  blackAndWhiteNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/21/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct GrayscaleNode: PatchNodeDefinition {
    static let patch = Patch.grayscale

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.asyncMedia(nil)],
                    label: "Media"
                )
            ],
            outputs: [
                .init(
                    label: "Grayscale",
                    type: .media
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

// Modifies image's metadata, rather than image itself.
@MainActor
func grayscaleEval(node: PatchNode) -> EvalResult {
    node.loopedEval(MediaEvalOpObserver.self) { values, mediaObservable, loopIndex in
        guard let mediaValue = mediaObservable.getUniqueMedia(from: values.first),
              let image = mediaValue.mediaObject.image else {
            return values.prevOutputs(node: node)
        }

        return mediaObservable.asyncMediaEvalOp(loopIndex: loopIndex,
                                                values: values,
                                                node: node) { [weak image] in
            var mediaValue = mediaValue
            
            switch await image?.setGrayscale() {
            case .success(let grayscaleImage):
                mediaValue.mediaObject = .image(grayscaleImage)
                return [mediaValue.portValue]
            case .failure(let error):
                Task { ReceivedStitchFileError(error: error) }
                return values.prevOutputs(node: node)
            default:
                return values.prevOutputs(node: node)
            }
        }
    }
}

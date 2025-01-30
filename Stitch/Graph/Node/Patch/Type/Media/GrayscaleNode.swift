//
//  blackAndWhiteNode.swift
//  Stitch
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
    node.loopedEval(MediaEvalOpObserver.self) { values, mediaObservable, loopIndex -> MediaEvalOpResult in
        let prevOutputs = values.prevOutputs(node: node)
        
        return mediaObservable.asyncMediaEvalOp(loopIndex: loopIndex,
                                                values: values,
                                                node: node) { [weak mediaObservable] in
            guard var mediaValue = await mediaObservable?.getUniqueMedia(inputPortIndex: 0,
                                                                         loopIndex: loopIndex),
                  let image = mediaValue.mediaObject.image else {
                return MediaEvalOpResult(from: prevOutputs)
            }
            
            switch await image.setGrayscale() {
            case .success(let grayscaleImage):
                mediaValue.mediaObject = .image(grayscaleImage)
                
                return MediaEvalOpResult(values: [.asyncMedia(mediaValue.mediaValue)],
                                         media: mediaValue.mediaObject)
            case .failure(let error):
                Task { ReceivedStitchFileError(error: error) }
                let values = await values.prevOutputs(node: node)
                return MediaEvalOpResult(from: values)
//            default:
//                let values = await values.prevOutputs(node: node)
//                let currentMedia = await mediaObservable?.currentMedia?.mediaObject
//                return MediaEvalOpResult(values: values,
//                                         media: currentMedia)
            }
        }
    }
}

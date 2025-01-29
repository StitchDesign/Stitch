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

    static let ephemeralObserverType = MediaEvalOpObserver.self
}

// Modifies image's metadata, rather than image itself.
@MainActor
func grayscaleEval(node: PatchNode) -> EvalResult {
    node.loopedEval(MediaEvalOpObserver.self) { values, mediaObservable, loopIndex -> MediaEvalOpResult in
        guard let mediaValue = mediaObservable.getUniqueMedia(from: values.first,
                                                              loopIndex: loopIndex),
              let image = mediaValue.mediaObject.image else {
            return MediaEvalOpResult(from: values.prevOutputs(node: node))
        }

        return mediaObservable.asyncMediaEvalOp(loopIndex: loopIndex,
                                                values: values,
                                                node: node) { [weak image] in
            var mediaValue = mediaValue
            
            switch await image?.setGrayscale() {
            case .success(let grayscaleImage):
                mediaValue.mediaObject = .image(grayscaleImage)
                
//                await MainActor.run { [weak mediaObservable] in
//                    mediaObservable?.currentMedia = mediaValue
//                }
                
                return MediaEvalOpResult(values: [mediaValue.portValue],
                                         media: mediaValue.mediaObject)
            case .failure(let error):
                Task { ReceivedStitchFileError(error: error) }
                let values = await values.prevOutputs(node: node)
                return MediaEvalOpResult(from: values)
            default:
                let values = await values.prevOutputs(node: node)
                let currentMedia = await mediaObservable.currentMedia?.mediaObject
                return MediaEvalOpResult(values: values,
                                         media: currentMedia)
            }
        }
    }
}

// TODO: move
struct MediaEvalOpResult {
    let values: PortValues
    var media: StitchMediaObject?
}

extension MediaEvalOpResult: NodeEvalOpResult {
    init(from values: PortValues) {
        self.values = values
        self.media = nil
    }
}

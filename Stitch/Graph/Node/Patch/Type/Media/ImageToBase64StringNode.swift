//
//  ImageToBase64StringNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/15/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func convertImageToBase64String(uiImage: UIImage) async -> StitchFileResult<String> {
    // 1 is highest quality;
    // but 0.1 seems fine, and gives much better perf.
    guard let string = uiImage
            .jpegData(compressionQuality: 0.1)?
            .base64EncodedString() else {

        return .failure(.imgToBase64Failed)
    }

    return .success(string)
}

struct ImageToBase64StringNode: PatchNodeDefinition {
    static let patch = Patch.imageToBase64String

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
                    label: "",
                    type: .string
                )
            ]
        )
    }

        static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

@MainActor
func imageToBase64StringEval(node: PatchNode) -> EvalResult {
    node.loopedEval(MediaEvalOpObserver.self) { values, asyncObserver, loopIndex in
        guard let media = asyncObserver.getUniqueMedia(from: values.first,
                                                       loopIndex: loopIndex),
              let inputImage = media.mediaObject.image else {
            return values.prevOutputs(node: node)
        }

        return asyncObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                              values: values,
                                              node: node) { [weak inputImage] in
            guard let inputImage = inputImage else {
                return await values.prevOutputs(node: node)
            }
            
            switch await convertImageToBase64String(uiImage: inputImage) {
            case .success(let string):
                let base64 = StitchStringValue(string,
                                               isLargeString: true)
                return [.string(base64)]
            case .failure(let error):
                Task { ReceivedStitchFileError(error: error) }
                return await values.prevOutputs(node: node)
            }
        }
    }
}

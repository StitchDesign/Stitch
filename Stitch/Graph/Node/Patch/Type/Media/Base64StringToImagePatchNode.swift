//
//  Base64ToImagePatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/15/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func convertBase64StringToImage(_ imageBase64String: String) async -> StitchFileResult<UIImage> {

    guard let data = Data(base64Encoded: imageBase64String),
          let image = UIImage(data: data) else {
        #if DEBUG
        log("convertBase64StringToImage: could not get data")
        #endif
        return .failure(.base64ToImgFailed)
    }

    // There's no "filename" for an image produced by a base-64 string
    image.accessibilityIdentifier = "Base64 Image"
    return .success(image)
}

struct Base64StringToImageNode: PatchNodeDefinition {
    static let patch = Patch.base64StringToImage

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.string(.init(""))],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .media
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

@MainActor
func base64StringToImageEval(node: PatchNode) -> EvalResult {
    node.loopedEval(MediaEvalOpObserver.self) { values, mediaObserver, loopIndex in
        let inputBase64String: String = values.first?.getString?.string ?? ""
        
        return mediaObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                              values: values,
                                              node: node) {
            switch await convertBase64StringToImage(inputBase64String) {
            case .success(let image):
                return [.asyncMedia(AsyncMediaValue(dataType: .computed,
                                                    mediaObject: .image(image)))]
            case .failure(let error):
                log("base64StringToImageEval error: \(error)")
                // TODO: do we always want to show the error?
                return await values.prevOutputs(node: node)
            }
        }
    }
}

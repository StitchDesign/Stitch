//
//  CoreMLClassifyNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/28/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import CoreML
import Vision

struct CoreMLClassifyNode: PatchNodeDefinition {
    static let patch = Patch.coreMLClassify

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.asyncMedia(nil)],
                    label: "Model"
                ),
                .init(
                    defaultValues: [.asyncMedia(nil)],
                    label: "Image"
                )
            ],
            outputs: [
                .init(
                    label: "Classification",
                    value: .string(.init(CORE_ML_NO_RESULTS))
                ),
                .init(
                    label: "Confidence",
                    type: .number
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

@MainActor
func coreMLClassifyEval(node: PatchNode) -> EvalResult {
    node.loopedEval(MediaEvalOpObserver.self) { values, mediaObserver, loopIndex in
        guard let modelMediaObject = mediaObserver.getUniqueMedia(from: values.first)?.mediaObject,
              let model = modelMediaObject.coreMLImageModel else {
            return node.defaultOutputs
        }
        
        return mediaObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                              values: values,
                                              node: node) { [weak model] in
            guard let model = model,
                  let image = values[safe: 1]?.asyncMedia?.mediaObject.image else {
                return node.defaultOutputs
            }
            
            let result = await visionClassificationRequest(for: model, with: image)
            return [.string(.init(result.identifier)),
                    .number(Double(result.confidence))]
        }
    }
}

// Async wrapper call to handle vision requests with completion handlers
func visionClassificationRequest(for model: VNCoreMLModel,
                                 with uiImage: UIImage) async -> VNClassificationObservation {
    return await withCheckedContinuation { continuation in
        visionClassificationRequest(for: model,
                                    with: uiImage) { result in
            continuation.resume(returning: result)
        }
    }
}

func visionClassificationRequest(for model: VNCoreMLModel,
                                 with uiImage: UIImage,
                                 complete: @escaping (VNClassificationObservation) -> Void) {
    // Processes vision request on background thread for perf.
    // Various operations here like creating a CIImage and completing the vision request
    // are computationally expensive.
    Task.detached(priority: .userInitiated) {
        // Request handler object for image classification tasks
        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                print("mlModelSideEffect error: couldn't create ML model request handler with error: ", error)
                fatalError()
            }
            guard let results = request.results as? [VNClassificationObservation] else {
                fatalError()
            }

            guard let classificationResult = results.first else {
                log("coreMLClassifyEval error: no classification result found.")
                fatalError()
            }
            //            log("classification result: \(classificationResult)")
            complete(classificationResult)
        }

        request.imageCropAndScaleOption = .centerCrop

        let ciImage = CIImage(image: uiImage)!

        let handler = VNImageRequestHandler(ciImage: ciImage)

        do {
            try handler.perform([request])
        } catch {
            log("mlModelSideEffect error: failed to perform classification.\n\(error.localizedDescription)")
            fatalError()
        }
    }
}

//
//  CoreMLClassifyNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/28/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import CoreML
@preconcurrency import Vision

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
        ImageClassifierOpObserver()
    }
}

extension CoreMLClassifyNode {
    static func coreMLEvalOp(media: GraphMediaValue,
                             mediaObserver: ImageClassifierOpObserver,
                             image: UIImage,
                             defaultOutputs: PortValues) async -> MediaEvalOpResult {
        guard let model = media.mediaObject.coreMLImageModel,
              let result = await mediaObserver.coreMlActor
            .visionClassificationRequest(for: model,
                                         with: image) else {
            return .init(from: defaultOutputs)
        }
        
        return .init(values: [
            .string(.init(result.identifier)),
            .number(Double(result.confidence))
        ],
                     media: media.mediaObject)
    }
}

@MainActor
func coreMLClassifyEval(node: PatchNode) -> EvalResult {
    node.loopedEval(ImageClassifierOpObserver.self) { values, mediaObserver, loopIndex in
        let currentMedia = node.getComputedMediaValue(loopIndex: loopIndex)
        let didMediaChange = currentMedia?.id != values.first?.asyncMedia?.id
        let defaultOutputs = node.defaultOutputs
        
        guard let image = node.getInputMedia(portIndex: 1,
                                             loopIndex: loopIndex)?.image else {
            return .init(from: defaultOutputs)
        }

        return mediaObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                              values: values,
                                              node: node) { [weak mediaObserver, weak image] () -> MediaEvalOpResult in
            // Create unique copy if media changed
            let media = didMediaChange ? await mediaObserver?.getUniqueMedia(inputPortIndex: 0,
                                                                             loopIndex: loopIndex)
                                       : currentMedia
            guard let media = media,
                  let image = image,
                  let mediaObserver = mediaObserver else {
                return .init(from: defaultOutputs)
            }
            
            return await CoreMLClassifyNode.coreMLEvalOp(media: media,
                                                         mediaObserver: mediaObserver,
                                                         image: image,
                                                         defaultOutputs: defaultOutputs)
        }
    }
}

final actor ImageClassifierActor {
    private var result: VNClassificationObservation?
    
    private func imageClassification(request: VNRequest, error: (any Error)?) {
        if let error = error {
            print("mlModelSideEffect error: couldn't create ML model request handler with error: ", error)
            fatalErrorIfDebug()
            self.result = nil
            return
        }
        guard let results = request.results as? [VNClassificationObservation] else {
            fatalErrorIfDebug()
            self.result = nil
            return
        }
        
        guard let classificationResult = results.first else {
            log("coreMLClassifyEval error: no classification result found.")
            fatalErrorIfDebug()
            self.result = nil
            return
        }
        //            log("classification result: \(classificationResult)")
        
        self.result = classificationResult
    }
    
    func visionClassificationRequest(for model: VNCoreMLModel,
                                     with uiImage: UIImage) -> VNClassificationObservation? {
        // Request handler object for image classification tasks
        let request = VNCoreMLRequest(model: model,
                                      completionHandler: imageClassification)
        
        request.imageCropAndScaleOption = .centerCrop
        
        let ciImage = CIImage(image: uiImage)!
        
        let handler = VNImageRequestHandler(ciImage: ciImage)
        
        do {
            // Request will update actor's variable
            try handler.perform([request])
        } catch {
            log("mlModelSideEffect error: failed to perform classification.\n\(error.localizedDescription)")
            fatalErrorIfDebug()
        }
        
        return self.result
    }
}


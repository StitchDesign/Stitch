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
                             defaultOutputs: PortValues) async -> PortValues {
        guard let model = media.mediaObject.coreMLImageModel,
              let result = await mediaObserver.coreMlActor
            .visionClassificationRequest(for: model,
                                         with: image) else {
            return defaultOutputs
        }
        
        return [
            .string(.init(result.identifier)),
            .number(Double(result.confidence))
        ]
    }
}

@MainActor
func coreMLClassifyEval(node: PatchNode) -> EvalResult {
    let defaultOutputs = node.defaultOutputs
    
    return node.loopedEval(ImageClassifierOpObserver.self) { (values, mediaObserver, loopIndex) -> MediaEvalOpResult in
        mediaObserver.mediaEvalOpCoordinator(inputPortIndex: 0,
                                             values: values,
                                             loopIndex: loopIndex,
                                             defaultOutputs: defaultOutputs) { media -> PortValues in
            guard let image = mediaObserver.imageInput else {
                return defaultOutputs
            }
            
            return mediaObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                                  values: values,
                                                  node: node) { [weak mediaObserver, weak image] in
                guard let image = image,
                      let mediaObserver = mediaObserver else {
                    return defaultOutputs
                }
                
                return await CoreMLClassifyNode.coreMLEvalOp(media: media,
                                                             mediaObserver: mediaObserver,
                                                             image: image,
                                                             defaultOutputs: defaultOutputs)
            }
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


//
//  CoreMLDetectionNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 3/5/23.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import CoreML
import Vision

struct CoreMLDetectionNode: PatchNodeDefinition {
    static let patch = Patch.coreMLDetection

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
                ),
                .init(
                    defaultValues: [.vnImageCropOption(.scaleFit)],
                    label: "Crop & Scale"
                )
            ],
            outputs: [
                .init(
                    label: "Detections",
                    type: .string
                ),
                .init(
                    label: "Confidence",
                    type: .number
                ),
                .init(
                    label: "Locations",
                    type: .position
                ),
                .init(
                    label: "Bounding Box",
                    type: .size
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

func coreMLDetectionDefaultOutputs(nodeId: NodeId, inputsCount: Int) -> Outputs {
    toOutputs(id: nodeId,
              offset: inputsCount,
              values:
                ("Detections", [.string(.init(CORE_ML_NO_RESULTS))]),
              ("Confidence", [.number(0)]),
              ("Locations", [.position(.zero)]),
              ("Bounding Box", [.size(.zero)])
    )
}

/*
 TODO: ObjectDetection is actually a one-to-many eval;
 i.e. one model + one image produces many detect objects (with their locations etc.);
 So, instead of evaluating by index, we should just grab the first value
 in each input and return lists in the outputs.
 */
@MainActor
func coreMLDetectionEval(node: PatchNode) -> EvalResult {
    return node.loopedEvalList(MediaEvalOpObserver.self) { values, mediaObserver in
        let defaultOutputs = node.defaultOutputsList

        guard let modelMediaObject = mediaObserver.getUniqueMedia(from: values.first,
                                                                  loopIndex: 0)?.mediaObject,
              let model = modelMediaObject.coreMLImageModel,
              let cropAndScaleOption = values[safe: 2]?.vnImageCropOption,
              let image = values[safe: 1]?.asyncMedia?.mediaObject.image else {
            // defaults/failures we still treat as "by index"
            return defaultOutputs
        }
        
        return mediaObserver.asyncMediaEvalOpList(node: node) { [weak model, weak image] in
            guard let model = model,
                  let image = image else {
                // Return same previous outputs list
                return defaultOutputs
            }
            
            let results: [VNRecognizedObjectObservation] = await visionDetectionRequest(for: model,
                                                                                        with: image,
                                                                                        vnImageCropOption: cropAndScaleOption)
            
            if results.isEmpty {
                //                log("coreMLDetectionEval: results were empty; returning existing outputs")
                return defaultOutputs
            }
            
            //            log("coreMLDetectionEval: result.description: \(results.description)")
            
            var labelsOutputLoop = [String]()
            var confidenceOutputLoop = [Double]()
            var locationOutputLoop = [StitchPosition]()
            var sizeOutputLoop = [CGSize]()
            
            let imageSize = image.size
            
            //            log("coreMLDetectionEval: results.count: \(results.count)")
            
            results.forEach { (result: VNRecognizedObjectObservation) in
                
                //                log("result.labels identifier: \(result.labels.map(\.identifier))")
                //                log("result.labels confidence: \(result.labels.map(\.confidence))")
                
                if let mostConfidentLabel = result.labels.mostConfidentLabel() {
                    
                    labelsOutputLoop.append(mostConfidentLabel.identifier)
                    
                    confidenceOutputLoop.append(Double(mostConfidentLabel.confidence))
                    
                    let rect = transformRect(
                        fromRect: result.boundingBox,
                        // viewSize is treated as imageSize
                        toViewSize: imageSize)
                    
                    locationOutputLoop.append(
                        .init(width: rect.minX,
                              height: rect.minY)
                    )
                    
                    sizeOutputLoop.append(
                        .init(width: rect.width,
                              height: rect.height))
                    
                }
                //                else {
                //                    log("coreMLDetectionEval: Could not find label for result: \(result)")
                //                }
            }
            
            return [
                labelsOutputLoop.map { PortValue.string(.init($0)) },
                confidenceOutputLoop.map(PortValue.number),
                locationOutputLoop.map(PortValue.position),
                sizeOutputLoop.map { PortValue.size(.init($0)) }
            ]
        }
    }
}

func visionDetectionRequest(for model: VNCoreMLModel,
                            with uiImage: UIImage,
                            vnImageCropOption: VNImageCropAndScaleOption) async -> [VNRecognizedObjectObservation] {
    return await withCheckedContinuation { continuation in
        visionObjectDetectionRequest(for: model,
                                     with: uiImage,
                                     vnImageCropOption: vnImageCropOption) { result in
            continuation.resume(returning: result)
        }
    }
}

func visionObjectDetectionRequest(for model: VNCoreMLModel,
                                  with uiImage: UIImage,
                                  vnImageCropOption: VNImageCropAndScaleOption,
                                  complete: @escaping ([VNRecognizedObjectObservation]) -> Void) {
    // Processes vision request on background thread for perf.
    // Various operations here like creating a CIImage and completing the vision request
    // are computationally expensive.
    Task.detached(priority: .userInitiated) {

        //    Task(priority: .high) {

        // .background /// causes crashes due to memory issues on iPad ?

        //    Task(priority: .background) {
        // Request handler object for object detection tasks
        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                print("mlModelSideEffect error: couldn't create ML model request handler with error: ", error)
                fatalError()
            }

            //            log("mlModelSideEffect: request: \(request)")

            guard let results = request.results as? [VNRecognizedObjectObservation],
                  results.first.isDefined else {
                //                log("mlModelSideEffect error: failed to perform object detection.")
                return complete([])
            }

            complete(results)
        }

        /*
         We preferably don't modify the image unless for camera orientation reasons.

         Best results seem to be from no cropping or scaling at all.

         Good guide to `imageCropAndScaleOption`:
         https://machinethink.net/blog/bounding-boxes/
         */
        // request.imageCropAndScaleOption = .centerCrop
        // request.imageCropAndScaleOption = .scaleFill
        request.imageCropAndScaleOption = vnImageCropOption

        let ciImage = CIImage(image: uiImage)!
        let handler = VNImageRequestHandler(ciImage: ciImage)

        do {
            try handler.perform([request])
        } catch {
            log("mlModelSideEffect error: failed to perform object detection.\n\(error.localizedDescription)")
        }
    }
}

extension [VNClassificationObservation] {
    func mostConfidentLabel() -> VNClassificationObservation? {
        Stitch.mostConfidentLabel(labels: self)
    }
}

func mostConfidentLabel(labels: [VNClassificationObservation]) -> VNClassificationObservation? {
    labels.max(by: {$0.confidence < $1.confidence }) ?? labels.first
}

// CoreML (for detection node at least) coordinate system starts bottom-left,
// whereas SwiftUI's starts top-left;
// this method corrects for that.
func transformRect(fromRect: CGRect, toViewSize: CGSize) -> CGRect {
    let height = fromRect.size.height * toViewSize.height
    let width = fromRect.size.width * toViewSize.width
    let x = fromRect.origin.x * toViewSize.width
    let y = (1 - fromRect.origin.y) * toViewSize.height - height
    return CGRect(x: x, y: y, width: width, height: height)
}

extension VNImageCropAndScaleOption: PortValueEnum {
    public static var allCases: [VNImageCropAndScaleOption] {
        [.centerCrop, .scaleFit, .scaleFill, .scaleFitRotate90CCW, .scaleFillRotate90CCW]
    }

    static var portValueTypeGetter: PortValueTypeGetter<VNImageCropAndScaleOption> {
        PortValue.vnImageCropOption
    }

    var label: String {
        switch self {
        case .centerCrop:
            return "Center Crop"
        case .scaleFit:
            return "Scale to Fit"
        case .scaleFill:
            return "Scale to Fill"
        case .scaleFitRotate90CCW:
            return "Scale to Fit 90°"
        case .scaleFillRotate90CCW:
            return "Scale to Fill 90°"
        }
    }
}

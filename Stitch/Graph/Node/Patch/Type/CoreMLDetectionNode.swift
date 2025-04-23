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
@preconcurrency import Vision

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
        VisionOpObserver()
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
    let defaultOutputs = node.defaultOutputsList
    let inputs = node.inputs
    
    guard let mediaObserver = node.ephemeralObservers?.first as? VisionOpObserver,
          let image = mediaObserver.imageInput,
          let cropAndScaleOption = inputs[safe: 2]?.first?.vnImageCropOption else {
        return .init(outputsValues: defaultOutputs)
    }
        
    let result: MediaEvalValuesListResult = mediaObserver
        .mediaEvalOpCoordinator(inputPortIndex: 0,
                                values: inputs,
                                loopIndex: 0,
                                defaultOutputs: defaultOutputs) { (media) -> PortValuesList in
            mediaObserver.asyncMediaEvalOpList(node: node) { [weak image] in
                guard let model = media.mediaObject.coreMLImageModel,
                      let image = image else {
                    // Return same previous outputs list
                    return defaultOutputs
                }
                
                let results: [VNRecognizedObjectObservation] = await mediaObserver.coreMlActor
                    .visionDetectionRequest(for: model,
                                            with: image,
                                            vnImageCropOption: cropAndScaleOption)
                
                if results.isEmpty {
                    return defaultOutputs
                }
                
                var labelsOutputLoop = [String]()
                var confidenceOutputLoop = [Double]()
                var locationOutputLoop = [StitchPosition]()
                var sizeOutputLoop = [CGSize]()
                
                let imageSize = image.size
                
                results.forEach { (result: VNRecognizedObjectObservation) in
                    if let mostConfidentLabel = result.labels.mostConfidentLabel() {
                        
                        labelsOutputLoop.append(mostConfidentLabel.identifier)
                        confidenceOutputLoop.append(Double(mostConfidentLabel.confidence))
                        
                        let rect = transformRect(
                            fromRect: result.boundingBox,
                            // viewSize is treated as imageSize
                            toViewSize: imageSize)
                        
                        locationOutputLoop.append(
                            .init(x: rect.minX,
                                  y: rect.minY)
                        )
                        
                        sizeOutputLoop.append(
                            .init(width: rect.width,
                                  height: rect.height))
                    }
                }
                
                return [
                    labelsOutputLoop.map { PortValue.string(.init($0)) },
                    confidenceOutputLoop.map(PortValue.number),
                    locationOutputLoop.map(PortValue.position),
                    sizeOutputLoop.map { PortValue.size(.init($0)) }
                ]
            }
        }
    
    return MediaEvalValuesListResult.createEvalResult(from: [result],
                                                      node: node)
}


final actor VisionOpActor {
    private var results: [VNRecognizedObjectObservation] = []
    
    private func visionRequestHandler(request: VNRequest, error: (any Error)?) {
        if let error = error {
            print("mlModelSideEffect error: couldn't create ML model request handler with error: ", error)
            fatalErrorIfDebug()
            self.results = []
        }
        
        //            log("mlModelSideEffect: request: \(request)")
        
        guard let results = request.results as? [VNRecognizedObjectObservation],
              results.first.isDefined else {
            //                log("mlModelSideEffect error: failed to perform object detection.")
            self.results = []
            return
        }
        
        self.results = results
    }
    
    func visionDetectionRequest(for model: VNCoreMLModel,
                                with uiImage: UIImage,
                                vnImageCropOption: VNImageCropAndScaleOption) -> [VNRecognizedObjectObservation] {
        // Request handler object for object detection tasks
        let request = VNCoreMLRequest(model: model,
                                      completionHandler: self.visionRequestHandler)
        
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
            // Request will update actor's variable
            try handler.perform([request])
        } catch {
            log("mlModelSideEffect error: failed to perform object detection.\n\(error.localizedDescription)")
        }

        return self.results
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
        @unknown default:
            fatalErrorIfDebug()
            return Self.centerCrop.label
        }
    }
}

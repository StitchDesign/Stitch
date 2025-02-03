//
//  QRCodeDetection.swift
//  Stitch
//
//  Created by Nicholas Arner on 04/05/24
//

import Foundation
import StitchSchemaKit
import SwiftUI
import CoreML
import Vision

struct QRCodeDetectionNode: PatchNodeDefinition {
    static let patch = Patch.qrCodeDetection

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.asyncMedia(nil)],
                    label: "Image"
                )
            ],
            outputs: [
                .init(
                    label: "QR Code Detected",
                    type: .bool
                ),
                .init(
                    label: "Message",
                    type: .string
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


@MainActor
func qrCodeDetectionEval(node: PatchNode) -> EvalResult {
    let defaultOutputs = node.defaultOutputs
    
    return node.loopedEval(MediaEvalOpObserver.self) { values, asyncObserver, loopIndex in
        asyncObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                              values: values,
                                              node: node) { [weak asyncObserver] in
            guard let media = await asyncObserver?.getUniqueMedia(inputMediaValue: values.first?.asyncMedia,
                                                                  inputPortIndex: 0,
                                                                  loopIndex: loopIndex),
                  let image = media.mediaObject.image else {
                return defaultOutputs
            }

            switch await image.detectQRCode() {
            case .success(let detectionResult):
                let message = detectionResult.message
                let originalBoundingBox = detectionResult.boundingBox
                
                // Apply a transformation to the origin to adjust for coordinate systems.
                // Flip the Y-axis and translate the origin to the top left corner.
                // Assume the image's coordinate system needs no change on the x-axis.
                let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -image.size.height)
                let transformedBoundingBox = originalBoundingBox.applying(transform)
                
                // Creating output positions, size remains the same
                let originPosition = StitchPosition(x: transformedBoundingBox.origin.x,
                                                    y: transformedBoundingBox.origin.y)
                let size = LayerSize(CGSize(width: transformedBoundingBox.size.width, height: transformedBoundingBox.size.height))
                
                return [.bool(true),
                        .string(.init(message)),
                        .position(originPosition),
                        .size(size)]
                
            case .failure(_):
                return [.bool(false),
                        .string(.init("")),
                        .position(.zero),
                        .size(.zero)]
            }
        }
    }
}

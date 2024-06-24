//
//  UIImageExtensionUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/15/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UIKit

// https://stackoverflow.com/questions/31803157/how-can-i-color-a-uiimage-in-swift

extension UIImage {
    /// Detect if a QR code is present in an image
    enum DetectionError: Error {
        case ciImageCreationFailed
        case detectorCreationFailed
        case noQRCodeDetected
    }

    struct QRCodeDetectionResult {
        let message: String
        let boundingBox: CGRect
    }

    func detectQRCode() async -> Result<QRCodeDetectionResult, DetectionError> {
        guard let newCIImage = CIImage(image: self) else {
            return .failure(.ciImageCreationFailed)
        }

        let context = CIContext()
        guard let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else {
            return .failure(.detectorCreationFailed)
        }

        let features = detector.features(in: newCIImage) as? [CIQRCodeFeature]
        if let qrCode = features?.first, let messageString = qrCode.messageString {
            let result = QRCodeDetectionResult(message: messageString, boundingBox: qrCode.bounds)
            return .success(result)
        } else {
            return .failure(.noQRCodeDetected)
        }
    }


    /// Set a grayscale filter to a `UIImage`.
    func setGrayscale() async -> StitchFileResult<UIImage> {
        let context = CIContext(options: nil)
        guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else {
            return .failure(.imageGrayscaleFailed)
        }
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        if let output = currentFilter.outputImage,
           let cgImage = context.createCGImage(output, from: output.extent) {
            let uiImage = UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
            uiImage.accessibilityIdentifier = self.accessibilityIdentifier
            return .success(uiImage)
        }
        return .failure(.imageGrayscaleFailed)
    }

    /// Creates a deep copy of a UIImage reference.
    func clone() -> UIImage? {
        guard let originalCgImage = self.cgImage, let newCgImage = originalCgImage.copy() else {
            return nil
        }

        let imageClone = UIImage(cgImage: newCgImage, scale: self.scale, orientation: self.imageOrientation)

        // Copies over some name if one was set in self
        imageClone.accessibilityIdentifier = self.accessibilityIdentifier
        return imageClone
    }

    var layerSize: LayerSize {
        self.size.toLayerSize
    }
}

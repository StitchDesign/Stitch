//
//  StitchMLModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/24.
//

import Foundation
import Vision

final class StitchMLModel: NSObject, NSCopying, Sendable {
    var model: VNCoreMLModel
    let originalURL: URL

    required init(originalURL: URL) throws {
        self.originalURL = originalURL

        let pathExtension = self.originalURL.pathExtension.uppercased()

        do {
            var mlModel: MLModel
            var vnModel: VNCoreMLModel

            // Compiled models are built different
            if pathExtension == "MLMODELC" {
                mlModel = try MLModel(contentsOf: self.originalURL)
                vnModel = try VNCoreMLModel(for: mlModel)
            } else {
                // TODO: make async again? Or are we okay because we only create this model inside an async function?
                let compiledModelUrl = try MLModel.compileModel(at: self.originalURL)
                mlModel = try MLModel(contentsOf: compiledModelUrl)
                vnModel = try VNCoreMLModel(for: mlModel)
            }

            // Just use filename, since `mlModel.modelDescription.description` and `mlModel.modelDescription.className` don't seem like good name candidates.
            vnModel.accessibilityLabel = originalURL.filename
            self.model = vnModel
        }
    }

    func copy(with zone: NSZone? = nil) -> Any {
        do {
            return try type(of: self).init(originalURL: originalURL)
        } catch {
            return self
        }
    }
}

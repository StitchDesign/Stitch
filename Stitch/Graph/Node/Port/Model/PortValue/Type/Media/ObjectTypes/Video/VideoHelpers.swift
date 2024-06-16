//
//  VideoHelpers.swift
//  prototype
//
//  Created by Christian J Clampitt on 6/21/21.
//

import Foundation
import StitchSchemaKit
import AVFoundation
import SwiftUI

// https://stackoverflow.com/questions/42520453/extract-frame-from-video-in-swift
extension AVAsset {
    func getThumbnail() async -> UIImage? {
        var generator: AVAssetImageGenerator

        generator = AVAssetImageGenerator(asset: self)
        generator.appliesPreferredTrackTransform = true

        // does not preserve original aspects?
        //    generator.maximumSize = defaultImageSizeInlineDisplay

        return getFrame(fromTime: 0, generator: generator)
    }
}

func getFrame(fromTime: Float64, generator: AVAssetImageGenerator) -> UIImage? {

    // MakeWithSeconds probably doesn't work, since you have sub-second times?
    let time: CMTime = CMTimeMakeWithSeconds(
        fromTime,
        // what is this preferredTimescale really doing?, why 600?
        preferredTimescale: 600)

    //    log("getFrame: time: \(time)")
    //    log("getFrame: CMTimeShow(time): \(CMTimeShow(time))")
    //    log("getFrame: time.seconds: \(time.seconds)")

    let image: CGImage
    do {
        try image = generator.copyCGImage(at: time, actualTime: nil)
        return UIImage(cgImage: image)
    } catch {
        return nil
    }
}

// https://stackoverflow.com/questions/10456564/rounding-numbers-to-specific-multiples

func roundToMultiple(n: Double, multiple: Double) -> Double {
    (n / multiple).rounded(toPlaces: 5) * multiple
}

extension AVPlayer {
    func getDuration() -> Double {
        guard let asset = self.currentItem?.asset else {
            return .zero
        }
        var durationInSeconds: Double = asset.duration.seconds

        // chop off a tiny bit, to avoid seeking to a 'blank' time
        durationInSeconds -= 0.05

        return durationInSeconds
    }

    var url: URL? { (self.currentItem?.asset as? AVURLAsset)?.url }
}

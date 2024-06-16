//
//  StitchVideo.swift
//  prototype
//
//  Created by Elliot Boschwitz on 7/17/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct VideoMetadata: Equatable, Hashable, Codable {
    // for non-scrub play
    var isScrubbing: Bool = false

    // effectively just 'what time will we show in the video'
    var scrubTime: Double = .zero // should be CMTime?

    // MARK: make sure there's some way for layers to auto play videos
    var playing: Bool = true

    var isLooped: Bool = true
}

//
//  GraphStep.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/8/21.
//

import Foundation
import StitchSchemaKit

/// Tracks frames in a Project for animation and rendering perf purposes.
struct GraphStepState: Equatable {
    var graphTime: TimeInterval = .zero
    var graphFrameCount: Int = 0
    var estimatedFPS: StitchFPS
}

//
//  Patch.swift
//  Stitch
//
//  Created by cjc on 2/3/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI

/* ----------------------------------------------------------------
 Patches: nodes on graph used for calculations etc. (not UI elements)
 ---------------------------------------------------------------- */

typealias PatchNodes = [PatchNode]

extension Patch {
    // Some nodes' eval methods draw directly from app-state (eg graph time or AVAudioRecorder) or internal node state (eg classic animation state),
    // and so their 'old vs new inputs' cannot be used to determine whether to run them.
    // Hence we always run their eval methods.
    var willAlwaysRunEval: Bool {

        switch self {

        case
            // nodes that rely on graphTime from app-state
            .time,
            .deviceTime,
            .stopwatch,
            .deviceMotion,
            .repeatingPulse,

            // TODO: only needs to run when prototype has been restarted or graph first opens?
            .whenPrototypeStarts,

            // repeatingAnimation node is something constantly checked, like a graph-time based node
            // TODO: can we come up with a better implementation?
            .repeatingAnimation,

            // nodes that (may) rely on AVPlayer metering from app-state
            // TODO: we don't need to run these nodes' evals if e.g. play=false etc.?
            .videoImport,
            .soundImport,
            .microphone,
            .sampleRange,

            // TODO: only needs to run when device orienation changes?
            .deviceInfo,

            .smoothValue, // is this an animation node?

            // TODO: only needs to run when input is changing? Is more like an animation node?
            .velocity,

            // a keyboard node's inputs might not change,
            // yet we may want to run its eval to change its outputs,
            // based on pressesBegan, etc.
            .keyboard,

            // Needs to subscribe to layer data, likely a more efficient way to do this
            .dragInteraction,
            
            .scrollInteraction:

            return true

        default:
            return false
        }
    }

    var isAnimationNode: Bool {
        switch self {
        case .classicAnimation,
             .cubicBezierAnimation,
             .repeatingAnimation,
             .springAnimation,
             .popAnimation,
             // scroll is technically an animation too
             .scrollInteraction,
            
            // NOT true for .nativeScrollInteraction ?
            
             // drag interaction's momentum is an animation
             .dragInteraction:
            return true
        default:
            return false
        }
    }

    var isARAnchor: Bool {
        switch self {
        case .arAnchor:
            return true
        default:
            return false
        }
    }

    static let excludedPatches: Set<Patch> = .init([
        // TODO: Fix `SampleRange` node with media
        .sampleRange,
        // Prefer type-specific pack and unpack patches
        .pack,
        .unpack
    ])
    
    // Previously used to filter some incomplete patches but currently we show all
    static var searchablePatches: [Patch] {
        var excludedPatches = Self.excludedPatches
        
        if !FeatureFlags.ENABLE_JS_NODE {
            excludedPatches.insert(.javascript)
        }
        
        return Patch.allCases.filter { patch in
            !excludedPatches.contains(patch)
        }
    }

    func supportedMediaType(portId: Int) -> NodeMediaSupport? {
        switch self {
        case .imageImport, .grayscale:
            return .single(.image)
        case .videoImport:
            return .single(.video)
        case .soundImport, .speaker:
            return .single(.audio)
        case .coreMLClassify, .coreMLDetection:
            if portId == 0 {
                return .single(.coreML)
            } else if portId == 1 {
                return .single(.image)
            } else {
                return .single(.coreML)
            }
        case .loopBuilder, .splitter, .loopInsert, .loopRemove:
            return .all
        default:
            return nil
        }
    }
    
    var usesInputsForLoopIndices: Bool {
        switch self {
        case .loopToArray, .commandsToShape:
            return true
        default:
            return false
        }
    }
    
    var supportsOneToManyIO: Bool {
        switch self {
        case .coreMLDetection:
            return true
        default:
            return false
        }
    }
}

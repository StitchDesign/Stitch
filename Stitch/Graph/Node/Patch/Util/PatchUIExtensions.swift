//
//  PatchUIExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension Patch {
    var inputsDisabled: Bool {
        switch self {
        case .time, .deviceTime, .deviceMotion, .deviceInfo, .whenPrototypeStarts, .mouse:
            return true
        default:
            return false
        }
    }

    var outputsDisabled: Bool {
        switch self {
        case .speaker, .restartPrototype, .hapticFeedback:
            return true
        default:
            return false
        }
    }

    var isInputsOnly: Bool {
        // if outputs are disabled, then we only have inputs.
        outputsDisabled
    }

    var isOutputsOnly: Bool {
        // if inputs are disabled, then we only have outputs.
        inputsDisabled
    }

    var isDoubleSided: Bool {
        return !isInputsOnly && !isOutputsOnly
    }

    func nodeUIColor(_ splitterType: SplitterType?) -> NodeUIColor {
        derivePatchNodeColor(for: self,
                             splitterType: splitterType)
    }

    var nodeUIKind: NodeUIKind {
        if isInputsOnly {
            return .inputsOnly
        } else if isOutputsOnly {
            return .outputsOnly
        } else {
            return .doubleSided
        }
    }

    var isInteractionPatchNode: Bool {
        switch self {
        case .dragInteraction, .pressInteraction, .scrollInteraction:
            return true
        default:
            return false
        }
    }

    // These are patches whose first inputs ALWAYS use dropdowns,
    // regardless of node-type.
    // (Different from eg a splitter patch that only uses a dropdown when its node-type = iamge.)
    var isMediaImportInput: Bool { self.usesCustomValueSpaceWidth }

    var usesCustomValueSpaceWidth: Bool {
        switch self {
        case .coreMLClassify, .coreMLDetection, .videoImport, .soundImport, .imageImport, .model3DImport, .grayscale:
            return true
        default:
            return false
        }
    }

    // Some patch nodes use labels
    // when their node type is a multifield port-value;
    // eg labels "X" and "Y" for .position.
    // TODO: NEED TO DISTINGUISH BETWEEN INPUT AND OUTPUT LABELS
    var multifieldUsesOverallLabel: Bool {
        switch self {
        case .transition, .classicAnimation, .delay, .dragInteraction, .scrollInteraction, .deviceInfo, .deviceMotion, .optionSender, .layerInfo, .triangleShape, .pressInteraction:
            return true
        default:
            return false
        }
    }

    // More like 'uses internal state',
    // since every PatchNode uses ComputedNodeState.
    var usesComputedState: Bool {
        switch self {
        case .dragInteraction, .pressInteraction,
                .scrollInteraction, // NOT TRUE for .nativeScrollInteraction?
                .springAnimation, .classicAnimation, .repeatingPulse, .repeatingAnimation:
            return true
        default:
            return false
        }
    }
}

extension Layer {
    var usesCustomValueSpaceWidth: Bool {
        switch self {
        case .image, .video, .model3D:
            return true
        default:
            return false
        }
    }
}

//
//  ComputedNodeState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/29/22.
//

import Foundation
import StitchSchemaKit
import RealityKit
import SwiftUI

//typealias PreviousValuesState = [Int: PortValues]

typealias ComputedNodesDict = [NodeId: ComputedNodeState]
typealias PreservedPortValues = [UserVisibleType: PortValue]

protocol NodeEphemeralObservable: AnyObject {
    func nodeTypeChanged(oldType: UserVisibleType,
                         newType: UserVisibleType,
                         kind: NodeKind)
    
    @MainActor func onPrototypeRestart()
}

extension NodeEphemeralObservable {
    /// Allows function to be optional by inherited observers.
    func nodeTypeChanged(oldType: UserVisibleType,
                         newType: UserVisibleType,
                         kind: NodeKind) { }
}

final class ComputedNodeState: NodeEphemeralObservable {
    // starts out empty when node has not yet been run;
    // filled every time we coerce- or parse-update
    var previousValue: PortValue?
    
    // Preserves value types
    var preservedValues: PreservedPortValues = .init()

    // set true when start-pulsed,
    // set false when end-pulsed
    // not affected by reset-pulsed
    var stopwatchIsRunning: Bool = false
    // stopwatch tracks when during graph time it was started
    var stopwatchStartGraphTime: TimeInterval?

    var queue: PortValues?

    var springAnimationState: SpringAnimationState?
    var classicAnimationState: ClassicAnimationState?
    var smoothValueAnimationState: SmoothValueAnimationState?

    // Maps data for some sample range node to its media ID
    var sampleRangeState: SampleRangeComputedState?
}

extension ComputedNodeState {
    func onPrototypeRestart() {
        self.previousValue = nil
        self.preservedValues = .init()
        self.stopwatchIsRunning = false
        self.stopwatchStartGraphTime = nil
        self.queue = nil
        self.springAnimationState = nil
        self.classicAnimationState = nil
        self.smoothValueAnimationState = nil
        self.sampleRangeState = nil
    }
    
    func nodeTypeChanged(oldType: UserVisibleType,
                         newType: UserVisibleType,
                         kind: NodeKind) {
        switch kind {
        case .patch(.classicAnimation):
            self.resetClassicAnimationStates(newType: newType)
        case .patch(.popAnimation), .patch(.springAnimation):
            self.resetSpringAnimationStates(newType: newType)
        default:
            return
        }
    }
}

extension ComputedNodeState {
    convenience init(classicAnimationState: ClassicAnimationState) {
        self.init()
        self.classicAnimationState = classicAnimationState
    }

    convenience init(smoothValueAnimationState: SmoothValueAnimationState) {
        self.init()
        self.smoothValueAnimationState = smoothValueAnimationState
    }

    convenience init(previousValue: PortValue) {
        self.init()
        self.previousValue = previousValue
    }

    convenience init(springAnimationState: SpringAnimationState) {
        self.init()
        self.springAnimationState = springAnimationState
    }

    convenience init(stopwatchIsRunning: Bool) {
        self.init()
        self.stopwatchIsRunning = stopwatchIsRunning
    }
}

struct SampleRangeComputedState: Equatable, Hashable {
    var start: Double?

    // Our means for tracking if a media object has been created
    var mediaId: MediaObjectId?

    func createOutputs(mediaObject: StitchMediaObject) -> PortValues {
        // Output value equates to the created sample range file
        var outputMediaValue: AsyncMediaValue?
        if let sampleRangeMediaId = self.mediaId {
            outputMediaValue = AsyncMediaValue(id: sampleRangeMediaId, 
                                               dataType: .computed,
                                               mediaObject: mediaObject)
        }

        return [.asyncMedia(outputMediaValue)]
    }
}

//
//  GraphStepManager.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/2/22.
//

import SwiftUI
import StitchSchemaKit

protocol GraphStepManagerDelegate: AnyObject {
    @MainActor
    func graphStepIncremented(elapsedProjectTime: TimeInterval,
                              frameCount: Int,
                              currentEstimatedFPS: StitchFPS)
}

/// Tracks frames in a Project for animation and rendering perf purposes.
/// **Instantiate this in a view (instead of the top App level) for better perf.**
@Observable
final class GraphStepManager: MiddlewareService {
    private weak var displayLink: CADisplayLink?

    @MainActor var graphFrameCount: Int = 0
    @MainActor var graphTimeStart: TimeInterval?
    @MainActor var graphTimeCurrent: TimeInterval?
    var estimatedFPS: StitchFPS = .defaultAssumedFPS

    /// Assigned to `StitchStore` and processes graph step changes.
    weak var delegate: GraphStepManagerDelegate?

    @MainActor
    var graphTime: TimeInterval {
        self.graphStepState.graphTime
    }


    @MainActor
    var graphStepState: GraphStepState {
        GraphStepState(graphTime: self.graphTimeCurrent ?? .zero,
                       graphFrameCount: self.graphFrameCount,
                       estimatedFPS: self.estimatedFPS)
    }

    // TIME-BASED GRAPH AND PREVIEW WINDOW UPDATES
    var lastGraphTime: TimeInterval = .zero

    // TIME-BASED GRAPH UI UPDATES
    var lastUIGraphTime: TimeInterval = .zero

    // TIME-BASED GRAPH-STEP-DRIVEN ANIMATIONS
    var lastGraphAnimationTime: TimeInterval = .zero

    @MainActor
    func start() {
        self.graphFrameCount = .zero

        let displayLink = CADisplayLink(target: self,
                                        selector: #selector(updateOnFrame))
        displayLink.add(to: .main, forMode: .common)
        displayLink.add(to: .main, forMode: .tracking)
        displayLink.add(to: .main, forMode: .default)

        self.displayLink = displayLink
    }

    @MainActor
    func stop() {
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.resetGraphStepState()
    }

    @MainActor
    func resetGraphStepState() {
        self.graphTimeStart = nil
        self.graphTimeCurrent = nil
        self.graphFrameCount = .zero
        self.lastGraphTime = .zero
        self.lastUIGraphTime = .zero
        self.lastGraphAnimationTime = .zero
        self.estimatedFPS = .defaultAssumedFPS
    }

    // Only for estimating actual device run-time FPS
    private var previousTimeInSeconds: Double = 0

    @MainActor
    @objc private func updateOnFrame(displaylink: CADisplayLink) {
        let graphFrameCount = self.graphFrameCount

        let currentTimestamp = displaylink.targetTimestamp
        let timeStart = self.graphTimeStart ?? currentTimestamp
        let elapsedProjectTime = currentTimestamp - timeStart

        // For calculating the ACTUAL run-time FPS
        // https://stackoverflow.com/questions/57937529/cadisplaylink-is-unable-to-achieve-a-constant-frame-rate-in-simulator
        let currentTimeInSeconds = Date().timeIntervalSince1970
        let elapsedTimeInSeconds = currentTimeInSeconds - self.previousTimeInSeconds
        self.previousTimeInSeconds = currentTimeInSeconds
        let actualFramesPerSecond: CGFloat = 1 / elapsedTimeInSeconds

        // The actual FPS:
        // - drops on large graph (e.g. drag the cable on the Humane demo)
        // - mostly constant on small graphs
        //            #if DEV_DEBUG
        //            log("GraphSteManager: updateOnFrame: actualFramesPerSecond: \(actualFramesPerSecond)")
        //            #endif

        // Update graph
        self.delegate?
            .graphStepIncremented(elapsedProjectTime: elapsedProjectTime,
                                  frameCount: graphFrameCount,
                                  currentEstimatedFPS: .init(actualFramesPerSecond))

        // Update internal state
        // displaylink.targetTimestamp can only be called from here so this
        // is where we'll save project start time
        self.graphTimeStart = timeStart
        self.graphTimeCurrent = elapsedProjectTime
        self.graphFrameCount += 1
    }
}

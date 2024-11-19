//
//  GraphMovement.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/26/22.
//

import SwiftUI
import StitchSchemaKit

// TODO: Finalize these numbers; have Adam take a look?
/*
 Per blog discussion:
 https://ariya.io/2011/10/flick-list-with-its-momentum-scrolling-and-deceleration
 and Github Javascript implementation:
 https://github.com/ariya/X2/blob/master/javascript/kineticmodel/KineticModel.js

 Some tricky areas:
 - how to translate the `duration = 2400` and `timeConstant = 1 + duration / 6` into our own terms? ... is 2400 just 24 milliseconds?
 - how to coordinate timeConstant and total animation steps?

 The fact that we're using GRAPH_MOMENTUM_VELOCITY_DAMP_FACTOR
 and a custom `duration` implies we're messing up the formula.
 */

// // Animation too long:
// let GRAPH_MOMENTUM_TIME_CONSTANT_DURATION: CGFloat = 350
// let GRAPH_MOMENTUM_TIME_CONSTANT_DURATION: CGFloat = 150
// let GRAPH_MOMENTUM_TIME_CONSTANT_DURATION: CGFloat = 100

// // Animation too fast:
// let GRAPH_MOMENTUM_TIME_CONSTANT_DURATION: CGFloat = 35

// // Animation just right?:
// let GRAPH_MOMENTUM_TIME_CONSTANT_DURATION: CGFloat = 60 // previously used
let GRAPH_MOMENTUM_TIME_CONSTANT_DURATION: CGFloat = 70

let GRAPH_MOMENTUM_TIME_CONSTANT: CGFloat = 1 + GRAPH_MOMENTUM_TIME_CONSTANT_DURATION / 6

// Why does blog / JS implementation use `6` here?
let GRAPH_MOMENTUM_END_STEP_COUNT: CGFloat = 6 * GRAPH_MOMENTUM_TIME_CONSTANT

let FREE_SCROLL_MOMENTUM_TIME_CONSTANT_DURATION: CGFloat = 70

let FREE_SCROLL_MOMENTUM_TIME_CONSTANT: CGFloat = 1 + GRAPH_MOMENTUM_TIME_CONSTANT_DURATION / 6

// Why does blog / JS implementation use `6` here?
let FREE_SCROLL_MOMENTUM_END_STEP_COUNT: CGFloat = 6 * GRAPH_MOMENTUM_TIME_CONSTANT

// Added; not originally part of the formula:
let GRAPH_MOMENTUM_MINIMUM_VELOCITY_MAGNITUDE: CGFloat = 1
let GRAPH_MOMENTUM_MAXIMUM_VELOCITY_MAGNITUDE: CGFloat = 1000

// Maps app seems to have a velocity lower than which it will
// not do any momentum movement;
// from manual testing UIKit velocities, this appears to be ~80 CGPoint/sec.
//let GRAPH_MOMENTUM_VELOCITY_THRESHOLD: CGFloat = 80
//let GRAPH_MOMENTUM_VELOCITY_THRESHOLD: CGFloat = 120
//let GRAPH_MOMENTUM_VELOCITY_THRESHOLD: CGFloat = 180
let GRAPH_MOMENTUM_VELOCITY_THRESHOLD: CGFloat = 220

// Less for inside preview window:
let FREE_SCROLL_MOMENTUM_VELOCITY_THRESHOLD: CGFloat = 40

// Added; not originally part of the formula:
// let GRAPH_MOMENTUM_VELOCITY_DAMP_FACTOR: CGFloat = 2 // previously
//let GRAPH_MOMENTUM_VELOCITY_DAMP_FACTOR: CGFloat = 2.4
//let GRAPH_MOMENTUM_VELOCITY_DAMP_FACTOR: CGFloat = 2.6
let GRAPH_MOMENTUM_VELOCITY_DAMP_FACTOR: CGFloat = 2.8

struct BoundaryNodesPositions {
    let north: CGPoint
    let south: CGPoint
    let west: CGPoint
    let east: CGPoint
}

@Observable
final class GraphMovementObserver {
    var localPosition = CGPoint.zero
    var zoomData: GraphZoom = .init()

    var localPreviousPosition = CGPoint.zero

    let graphMultigesture = GraphMultigesture()

    /*
     Non-nil when graph translation is such that eg eastern-most node would be at or past the western-border.

     Set nil when GraphDragEnded or eg eastern-most node moves away from western-border.
     */

    // Max translation in a given direction;
    // eg. `graphOffset.localPreviousPosition.height + maxTranslationY` = new position for graph
    var maxTranslationX: CGFloat?
    var maxTranslationY: CGFloat?

    // Used to determine, during a gesture that would extend past the border,
    // whether we've started to move away from the border or not.
    //    var lastInvalidTranslation: CGSize?
    var lastInvalidTranslationX: CGFloat?
    var lastInvalidTranslationY: CGFloat?

    var graphBoundOriginAtStart: GraphOriginAtStart?

    /*
     Left ie west side.
     True just when eastern node is already at or past western border.
     If true we don't apply the special border-checking logic.
     Set false as soon as eastern node crosses over to the right of the western border again
     */
    var currentlyOffsidesWest: Bool?

    // Did the western-most node on the graph start to the east of the eastern border?
    var currentlyOffsidesEast: Bool?

    // Did the northern-most node on the graph start to the south of the southern border?
    var currentlyOffsidesSouth: Bool?

    // Did the southern-most node on the graph start to the north of the north border?
    var currentlyOffsidesNorth: Bool?

    // Set true just when scrolling via trackpad.
    var wasTrackpadScroll = false

    var momentumState = MomentumAnimationState()
    
    var boundaryNodes: BoundaryNodesPositions?
}

extension GraphMovementObserver {
    var shouldRunY: Bool {
        momentumState.shouldRunY
    }
    var shouldRunX: Bool {
        momentumState.shouldRunX
    }

    // Do we need to run this momentum?
    var shouldRun: Bool {
        shouldRunY || shouldRunX
    }

    var stepY: CGFloat {
        momentumState.stepY
    }

    var stepX: CGFloat {
        momentumState.stepX
    }

    var amplitude: CGPoint {
        momentumState.amplitude
    }

    var delta: CGPoint {
        momentumState.delta
    }

    func resetGraphMovement() {
        self.localPreviousPosition = self.localPosition
        self.momentumState = resetMomentum(self.momentumState)
    }
    
    func stopNodeMovement() {
        self.draggedCanvasItem = nil
        self.lastCanvasItemTranslation = .zero
        self.accumulatedGraphTranslation = .zero
        self.runningGraphTranslationBeforeNodeDragged = nil
    }
}

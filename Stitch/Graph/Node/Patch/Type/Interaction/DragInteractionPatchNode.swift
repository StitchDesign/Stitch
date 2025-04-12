//
//  DragInteractionPatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct DragInteractionNode: PatchNodeDefinition {
    static let patch = Patch.dragInteraction

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [interactionIdDefault],
                    label: "Layer"
                ),
                .init(
                    defaultValues: [.bool(true)],
                    label: "Enabled"
                ),
                .init(
                    defaultValues: [.bool(false)],
                    label: "Momentum"
                ),
                .init(
                    defaultValues: [.position(StitchPosition.zero)],
                    label: "Start"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Reset"
                ),
                .init(
                    defaultValues: [.bool(false)],
                    label: "Clip"
                ),
                .init(
                    defaultValues: [.position(StitchPosition.zero)],
                    label: "Min"
                ),
                .init(
                    defaultValues: [.position(StitchPosition.zero)],
                    label: "Max"
                )
            ],
            outputs: [
                .init(
                    label: LayerInputPort.position.label(),
                    type: .position
                ),
                .init(
                    label: "Velocity",
                    type: .size
                ),
                .init(
                    label: "Translation",
                    type: .size
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        DragInteractionNodeState()
    }
}

final class DragInteractionNodeState: NodeEphemeralObservable {
    // for when user has dragged the layer and momentum is enabled
    var momentum = MomentumAnimationState()

    // TODO: rename to `linearAnimation` since used by both `reset` and `start`
    // linear movement back to start position
    // Note that `reset` duration is function of distance
    var reset = ScrollAnimationState()
    
    // Keeps track of drag state to detect last cycle of dragging (for momentum purposes)
    var wasDragging = false
    
    // Updates whenever drag ends so a new drag increments from here, fixing issue where values could constantly increment
    var prevPositionStart: CGPoint = .zero
    
    func onPrototypeRestart(document: StitchDocumentViewModel) {
        self.momentum = .init()
        self.reset = .init()
        self.wasDragging = false
        self.prevPositionStart = .zero
    }
}

/*
 This node eval is called in several different cases,
 and we use guard statements to handle the d

 1. after deserialization or graph reset: just extend the outputs
 2. after user finishes manually dragging a layer: maybe run momentum
 */
@MainActor
func dragInteractionEval(node: PatchNode,
                         graphState: GraphState) -> ImpureEvalResult {

    return node.loopedEval(DragInteractionNodeState.self,
                           graphState: graphState) { values, dragState, interactiveLayer, loopIndex in
        dragInteractionEvalOp(
            values: values,
            loopIndex: loopIndex,
            interactiveLayer: interactiveLayer,
            state: dragState,
            graphTime: graphState.graphStepState.graphTime,
            fps: graphState.graphStepState.estimatedFPS)
    }
                           .toImpureEvalResult()
}

// We should pulse whenever the time in the input and the time on the graph are the same,
// EXCEPT for when the project first starts (ie project open, graph reset, etc.)
func _shouldPulse(_ inputPulseTime: TimeInterval,
                  _ graphTime: TimeInterval) -> Bool {
    if inputPulseTime == .zero && graphTime == .zero {
        // ie do not pulse when both the input and the graph's time are at 0
        return false
    } else {
        return inputPulseTime == graphTime
    }
}

extension TimeInterval {
    func shouldPulse(_ time: TimeInterval) -> Bool {
        _shouldPulse(self, time)
    }
}

@MainActor
func dragInteractionEvalOp(values: PortValues,
                           loopIndex: Int,
                           interactiveLayer: InteractiveLayer,
                           state: DragInteractionNodeState,
                           graphTime: TimeInterval,
                           fps: StitchFPS) -> ImpureEvalOpResult {
    
    
    let dragEnabled: Bool = values[safeIndex: DragNodeInputLocations.isEnabled]?.getBool ?? false
    let momentumEnabled: Bool = values[safeIndex: DragNodeInputLocations.isMomentumEnabled]?.getBool ?? false
    let startingPoint: CGPoint = values[safeIndex: DragNodeInputLocations.startPoint]?.getPoint ?? .zero
    let resetPulse: TimeInterval = values[safeIndex: DragNodeInputLocations.reset]?.getPulse ?? .zero
    
    let clippingEnabled = values[safeIndex: DragNodeInputLocations.clippingEnabled]?.getBool ?? false
    let min = values[safeIndex: DragNodeInputLocations.min]?.getPoint ?? .zero
    let max = values[safeIndex: DragNodeInputLocations.max]?.getPoint ?? .zero
        
    // Note: If we can't find the output, it's because we reset the prototype, and so should be starting at 0,0 again anyway.
    // Note: also technically the currentOutput ?
        
    let previousStartingPoint: CGPoint = values[safeIndex: 8]?.getPoint ?? .zero
    
    let prevVelocity: CGPoint = values[safeIndex: 9]?.getSize?.asCGSize?.toCGPoint ?? .zero
    let shouldMomentumStart = momentumEnabled &&
        interactiveLayer.dragStartingPoint == nil &&
        state.wasDragging
    
    let isCurrentlyDragged = interactiveLayer.isDown
    
    // Update previous position when drag ends so that when next drag starts, we increment from a constant
    // previous value, fixing issue where re-using live previous output leads to constantly incrementing values
    if !isCurrentlyDragged {
        state.prevPositionStart = previousStartingPoint
    }
    
    var newOutput = interactiveLayer.getDraggedPosition(startingPoint: state.prevPositionStart)
    
    // Caps the position just if `clippingEnabled`
    let cap = { (p: CGPoint) in
        p.maybeCap(isClipped: clippingEnabled, min: min, max: max)
    }
    
    // ALWAYS "CAP" position, regardless
    let capOpOnlyValues: PortValues = [
        // basically our no-op
        PortValue.position(cap(newOutput)),
        .size(interactiveLayer.dragVelocity.toLayerSize),
        .size(interactiveLayer.dragTranslation.toLayerSize)
    ]

    let capOpOnly = ImpureEvalOpResult(outputs: capOpOnlyValues,
                                       willRunAgain: false)
    
    /*
     Always check first:
     (1) whether we received a pulse and need to do `reset` and whether the `reset` will be:
     (a) some linear animation (= momentum enabled), or
     (b) an instant reset
     
     (2) whether we have some in-progress linear animation (i.e. state.reset.frame != 0) that we need to continue.
     
     (1) takes precedence over (2) and any running momentum from a drag,
     since pressing `reset` overrides any active reset animation or current
     */
    
    let receivedResetPulse = resetPulse.shouldPulse(graphTime) || graphTime.graphJustStarted
    
    // Save is dragging state for next cycle
    state.wasDragging = interactiveLayer.dragStartingPoint.isDefined
    
    // RESET PULSE RECEVIED
    
    if receivedResetPulse {
        // log("had reset pulse")
        guard momentumEnabled else {
            // log("had reset pulse but momentum not enabled")
            
            // Update node's currently tracked drag value
            let resetInputValue = cap(startingPoint)
            
            return .init(
                // go immediately back to start position
                outputs: [.position(resetInputValue),
                          .size(interactiveLayer.dragVelocity.toLayerSize),
                          .size(interactiveLayer.dragTranslation.toLayerSize)],
                willRunAgain: false // don't need to run again
            )
        }
        
        // log("had reset pulse and momentum enabled; so will start animation")
        state.momentum = startMomentum(
            // Can create a fresh state at this index;
            // but leave the other states alone
            MomentumAnimationState(),
            // zoom:
            1.0, // TODO: what zoom to use here?
            .zero,
            threshold: FREE_SCROLL_MOMENTUM_VELOCITY_THRESHOLD)
        
        // TODO: derive distance
        // TODO: reset `momentum` state as well?
        state.reset = ScrollAnimationState(
            startValue: newOutput.toCGSize,
            toValue: startingPoint.toCGSize,
            frameCount: 1, // as if already started
            distance: calcScrollAnimationDistance(start: newOutput.toCGSize,
                                                  end: startingPoint.toCGSize))
        
        // Update node's currently tracked drag value
        let resetOutputValue = cap(newOutput)
        
        return .init(
            outputs: [PortValue.position(resetOutputValue),
                      .size(interactiveLayer.dragVelocity.toLayerSize),
                      .size(interactiveLayer.dragTranslation.toLayerSize)],
            willRunAgain: true
        )
    } // if receivedResetPulse
    
    // LINEAR ANIMATION IN PROGRESS
    // (`reset` or `startInput`)
    
    if state.reset.frameCount != 0 {
        
        //        log("had reset or start input animation in progress")
        
        state.reset.frameCount += 1
        
        // TODO: implement proper formula here
        let longX = state.reset.distance.width > 500
        let longY = state.reset.distance.height > 500.0
        let duration = (longX || longY) ? 0.5 : 0.2
        
        let (newX, shouldRunX) = runAnimation(
            toValue: state.reset.toValue.width,
            duration: duration,
            difference: state.reset.distance.width,
            startValue: state.reset.startValue.width,
            curve: .linear,
            currentFrameCount: Int(state.reset.frameCount),
            fps: fps)
        
        let (newY, shouldRunY) = runAnimation(
            toValue: state.reset.toValue.height,
            duration: duration,
            difference: state.reset.distance.height,
            startValue: state.reset.startValue.height,
            curve: .linear,
            currentFrameCount: Int(state.reset.frameCount),
            fps: fps)
        
        newOutput = CGPoint(x: newX, y: newY)
        
        if shouldRunX || shouldRunY {
            // log("had reset or start input animation in progress: need to run again")
            return .init(
                outputs: [PortValue.position(cap(newOutput)),
                .size(interactiveLayer.dragVelocity.toLayerSize),
                .size(interactiveLayer.dragTranslation.toLayerSize)],
                willRunAgain: true
            )
        } else {
            // log("had reset or start input animation in progress: don't need to run again")
            // If we don't need to run the animation anymore,
            // then we can return `runAgain = false`
            // and reset the sate
            state.reset = ScrollAnimationState()
            return .init(
                outputs: [PortValue.position(cap(newOutput)),
                .size(interactiveLayer.dragVelocity.toLayerSize),
                .size(interactiveLayer.dragTranslation.toLayerSize)],
                willRunAgain: false
            )
        }
    } // if state.reset.frameCount != 0
    
    // HANDLING MOMENTUM
    
    // When Enabled input = false, we can still handle a reset, but we just return the current output
    guard dragEnabled else {
        return ImpureEvalOpResult(outputs: [
            PortValue.position(previousStartingPoint), // reuse current output
            .size(.zero), // velocity and translation become zero
            .size(.zero)
        ],
                                  willRunAgain: false)
    }
    
    guard momentumEnabled else {
        // log("dragInteractionEvalOp: GUARD: momentum disabled")
        return capOpOnly
    }
    
    if shouldMomentumStart {
        state.momentum = startMomentum(
                    // Can create a fresh state at this index;
                    // but leave the other states alone
                    MomentumAnimationState(),
                    // zoom:
                    1.0, // TODO: what zoom to use here?
                    prevVelocity,
                    threshold: FREE_SCROLL_MOMENTUM_VELOCITY_THRESHOLD)
    }
    
    let result = runMomentum(
        state.momentum,
        shouldRunX: state.momentum.shouldRunX,
        shouldRunY: state.momentum.shouldRunY,
        x: newOutput.x,
        y: newOutput.y)
    
    newOutput.x = result.x
    newOutput.y = result.y
    state.momentum = result.momentumState
    
    if state.momentum.didXMomentumFinish {
        // log("dragInteractionEvalOp: momentum x finished")
        state.momentum.shouldRunX = false
    }
    
    if state.momentum.didYMomentumFinish {
        // log("dragInteractionEvalOp: momentum y finished")
        state.momentum.shouldRunY = false
    }
    
    // Cancel momentum if momentum state finished or if user initiated a drag
    let shouldCancelMomentum = !state.momentum.shouldRun || isCurrentlyDragged
    if shouldCancelMomentum {
        state.momentum = resetMomentum(state.momentum)
        // log("dragInteractionEvalOp: will not run again")
        
        // If we're done running momentum,
        // we should also update the drag starting point.
         return .init(
            outputs: [.position(cap(newOutput)),
                      .size(interactiveLayer.dragVelocity.toLayerSize),
                      .size(interactiveLayer.dragTranslation.toLayerSize)],
            willRunAgain: false
        )
    }
    // else: should run again
    else {
        // log("dragInteractionEvalOp: will run again: animationState is now: \(animationState)")
        return .init(
            outputs: [.position(cap(newOutput)),
                      .size(interactiveLayer.dragVelocity.toLayerSize),
                      .size(interactiveLayer.dragTranslation.toLayerSize)],
            willRunAgain: true
        )
    }
}

extension CGPoint {
    func maybeCap(isClipped: Bool, min: CGPoint, max: CGPoint) -> Self {
        isClipped ? capPosition(self, min: min, max: max) : self
    }
}

func capPosition(_ position: CGPoint,
                 min: CGPoint,
                 max: CGPoint) -> CGPoint {

    //    log("capPosition: position was: \(position)")

    var position = position

    // Min input: top left corner
    let minX: Double = min.x // -25
    let minY: Double = min.y // -25

    // Max input: bottom right corner
    let maxX: Double = max.x // 25
    let maxY: Double = max.y // 25

    if position.y < minY {
        //        log("capPosition: minY")
        position.y = minY
    }
    if position.y > maxY {
        //        log("capPosition: maxY")
        position.y = maxY
    }
    if position.x < minX {
        //        log("capPosition: minX")
        position.x = minX
    }
    if position.x > maxX {
        //        log("capPosition: maxY")
        position.x = maxX
    }

    //    log("capPosition: position is now: \(position)")

    return position
}

/// This is only for DragInteractionNode eval
func calcScrollAnimationDistance(start: CGSize, end: CGSize) -> CGSize {
    let xDistance = end.width - start.width
    let yDistance = end.height - start.height
    return CGSize(width: xDistance, height: yDistance)
}

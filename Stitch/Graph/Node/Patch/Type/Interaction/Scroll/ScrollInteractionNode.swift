//
//  ScrollInteractionNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/10/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension ScrollMode: PortValueEnum {
    static let scrollModeDefault = Self.free

    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.scrollMode
    }

    var display: String {
        switch self {
        case .free:
            return "Free"
        case .paging:
            return "Paging"
        case .disabled:
            return "Disabled"
        }
    }
}

extension ScrollJumpStyle: PortValueEnum {
    static let scrollJumpStyleDefault = Self.instant

    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.scrollJumpStyle
    }

    var display: String {
        switch self {
        case .animated:
            return "Animated"
        case .instant:
            return "Instant"
        }
    }
}

extension ScrollDecelerationRate: PortValueEnum {
    static let scrollDecelerationRateDefault = Self.normal

    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.scrollDecelerationRate
    }

    var display: String {
        switch self {
        case .normal:
            return "Normal"
        case .fast:
            return "Fast"
        }
    }
}

struct ScrollInteractionNode: PatchNodeDefinition {
    static let patch = Patch.scrollInteraction

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [interactionIdDefault],
                    label: "Layer",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [scrollModeDefault],
                    label: "Scroll X",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [scrollModeDefault],
                    label: "Scroll Y",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.size(.zero)],
                    label: "Content Size",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.bool(false)],
                    label: "Direction Locking",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.size(.zero)],
                    label: "Page Size",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.size(.zero)],
                    label: "Page Padding",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.scrollJumpStyle(.scrollJumpStyleDefault)],
                    label: "Jump Style X",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Jump to X",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Jump Position X",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.scrollJumpStyle(.scrollJumpStyleDefault)],
                    label: "Jump Style Y",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Jump to Y",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Jump Position Y",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.scrollDecelerationRate(.scrollDecelerationRateDefault)],
                    label: "Deceleration Rate",
                    isTypeStatic: true
                )
            ],
            outputs: [
                .init(
                    label: LayerInputPort.position.label(),
                    type: .position
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        ScrollInteractionState()
    }
}

@MainActor
func scrollInteractionEval(node: NodeViewModel,
                           graphState: GraphState) -> ImpureEvalResult {
    
    node.getLoopedEvalResults(ScrollInteractionState.self,
                              graphState: graphState) { values, scrollState, interactiveLayer, _ in
        let directionLockingEnabled = values[safeIndex: ScrollNodeInputLocations.directionLocking]?
                   .getBool ?? false
        let xScrollMode: ScrollMode = values[safeIndex: ScrollNodeInputLocations.xScrollMode]?.getScrollMode ?? .disabled
        let yScrollMode: ScrollMode = values[safeIndex: ScrollNodeInputLocations.yScrollMode]?.getScrollMode ?? .disabled
        
        let isDisabledScrollModeX = xScrollMode == .disabled
        let isDisabledScrollModeY = yScrollMode == .disabled
        
        let shouldRubberBand = !interactiveLayer.dragStartingPoint.isDefined

        if shouldRubberBand {
            return totalScrollInteractionEvalOp(values: values,
                                                scrollState: scrollState,
                                                interactiveLayer: interactiveLayer,
                                                graphTime: graphState.graphStepState.graphTime)
        }
        // Normal drag--no rubberbanding yet
        else {
            var translationSize = interactiveLayer.dragTranslation
            
            // if scroll direction locking input is enabled but not yet set,
            // set it now.
            if scrollState.scrollDirectionLocked == .none,
               directionLockingEnabled {
                
                if translationSize.height.abs > translationSize.width.abs {
                    //            log("updateOnScrolled: direction locking initialized to vertical")
                    scrollState.scrollDirectionLocked = .vertical
                } else if translationSize.width.abs > translationSize.height.abs {
                    //            log("updateOnScrolled: direction locking initialized to horizontal")
                    scrollState.scrollDirectionLocked = .horizontal
                }
                // don't set locking if translation's height == width
                // else { ... }
            }
            
            let startingDragPoint: CGPoint? = interactiveLayer.dragStartingPoint
            
            if directionLockingEnabled {
                if scrollState.scrollDirectionLocked == .vertical {
                    //            log("updateOnScrolled: Removing x dimension from velocity and translation")
                    //                           velocityAtIndex.width = 0
                    translationSize.width = 0
                } else if scrollState.scrollDirectionLocked == .horizontal {
                    //            log("updateOnScrolled: Removing y dimension from velocity and translation")
                    //                           velocityAtIndex.height = 0
                    translationSize.height = 0
                }
            }
            
            if isDisabledScrollModeX {
                translationSize.width = 0
            }
            
            if isDisabledScrollModeY {
                translationSize.height = 0
            }
            
            let newPosition = onScroll(
                translationSize: translationSize,
                previousPosition: startingDragPoint ?? .zero,
                position: interactiveLayer.layerPosition,
                size: interactiveLayer.childSize,
                parentSize: interactiveLayer.parentSize)
            
            // Initialize scroll mode state
            scrollState.initializeScrollMode(\.xScroll, from: xScrollMode)
            scrollState.initializeScrollMode(\.yScroll, from: yScrollMode)
            

            scrollState.lastDragStartingPoint = interactiveLayer.dragStartingPoint
            
            return .init(outputs: [.position(newPosition)])
        }
    }
                    .toImpureEvalResult() //defaultOutputs: ScrollInteractionNode.defaultScrollInteractionNodeOutputs)
}

/*
 Each dimension needs to be handled separately.
 */
@MainActor
func totalScrollInteractionEvalOp(values: PortValues,
                                  scrollState: ScrollInteractionState,
                                  interactiveLayer: InteractiveLayer,
                                  graphTime: TimeInterval) -> ImpureEvalOpResult {
    
    let pageSize = values[safe: ScrollNodeInputLocations.pageSize]?.getSize?
        .asCGSize(interactiveLayer.parentSize) ?? .zero
    let pagePadding = values[safe: ScrollNodeInputLocations.pagePadding]?.getSize?.asAlgebraicCGSize ?? .zero
    
    let xScrollMode: ScrollMode = values[safeIndex: ScrollNodeInputLocations.xScrollMode]?.getScrollMode ?? .disabled
    
    let yScrollMode: ScrollMode = values[safeIndex: ScrollNodeInputLocations.yScrollMode]?.getScrollMode ?? .disabled
    
//    let contentSize: CGSize = values.scrollContentSize?.asAlgebraicCGSize ?? .zero
    
    let jumpStyleX: ScrollJumpStyle = values.scrollJumpStyleX ?? .scrollJumpStyleDefault
    let scrollJumpToX: TimeInterval = values.scrollJumpToX ?? .zero
    let scrollJumpPositionX: Double = values.scrollJumpPositionX ?? .zero
    
    let jumpStyleY: ScrollJumpStyle = values.scrollJumpStyleY ?? .scrollJumpStyleDefault
    let scrollJumpToY: TimeInterval = values.scrollJumpToY ?? .zero
    let scrollJumpPositionY: Double = values.scrollJumpPositionY ?? .zero
    
    var currentPosition: CGPoint = values[safeIndex: ScrollNodeInputLocations.layerPosition]?.getPoint ?? .zero
    
    let isDisabledScrollModeX = xScrollMode == .disabled
    let isDisabledScrollModeY = yScrollMode == .disabled
    
    // These are set in LayerDragEnded for the entire scroll state
    // (i.e. both axes, since parent and child size do not vary by x vs y);
    // e.g. see `updateOnScrollEnded`.
    
    // should we run the y-axis animation again?
    var shouldRunYAgain = true
    
    // should we run the x-axis animation again?
    var shouldRunXAgain = true
    
    // In non-jump cases, we create the animation state in the LayerDragEnded handler,
    // and then increment here.
    //
    scrollState.yScroll = scrollState.yScroll.incrementFrame
    scrollState.xScroll = scrollState.xScroll.incrementFrame
    
    var hadJumpX = false
    var hadJumpY = false
    
    // TODO: the jump pulses should only be mutually exclusive if `DirectionLocking = true`
    if scrollJumpToY == graphTime {
        log("totalScrollInteractionEvalOp: HAD JUMP TO Y PULSE")
        let scrollModeResult = _handleYJumpPulseReceived(
            state: scrollState,
            jumpStyleY: jumpStyleY,
            currentOutput: currentPosition.y,
            scrollJumpPositionY: scrollJumpPositionY,
            childSize: interactiveLayer.childSize.height,
            parentSize: interactiveLayer.parentSize.height)
        
        currentPosition.y = scrollModeResult.position
        scrollState.yScroll = scrollModeResult.scrollMode
        shouldRunYAgain = scrollModeResult.shouldRunAgain
        hadJumpY = true
    }
    
    if scrollJumpToX == graphTime {
        log("totalScrollInteractionEvalOp: HAD JUMP TO X PULSE")
        let scrollModeResult = _handleXJumpPulseReceived(
            state: scrollState,
            jumpStyleX: jumpStyleX,
            currentOutput: currentPosition.x,
            scrollJumpPositionX: scrollJumpPositionX,
            childSize: interactiveLayer.childSize.width,
            parentSize: interactiveLayer.parentSize.width)
        
        currentPosition.x = scrollModeResult.position
        scrollState.xScroll = scrollModeResult.scrollMode
        shouldRunXAgain = scrollModeResult.shouldRunAgain
        hadJumpX = true
    }
    
    // NON-JUMP CASES
    
    // HANDLE Y AXIS
    
    switch scrollState.yScroll {
        
    case .none:
        shouldRunYAgain = false
        
    case .paging(let paging):
        // Even if we have a paging state,
        // we need to check for rubberbanding,
        // which takes priority over paging
        let pagingResultY = handlePaging(currentOutput: currentPosition.y,
                                         paging: paging,
                                         childSize: interactiveLayer.childSize.height,
                                         parentSize: interactiveLayer.parentSize.height,
                                         previousDragPosition: scrollState.lastDragStartingPoint?.y,
                                         velocityAtIndex: interactiveLayer.dragVelocity.height,
                                         pageSize: pageSize.height,
                                         pagePadding: pagePadding.height,
                                         hadJump: hadJumpY, 
                                         isDisabledScrollMode: isDisabledScrollModeY)
        
        currentPosition.y = pagingResultY.position
        scrollState.yScroll = pagingResultY.scrollMode
        shouldRunYAgain = pagingResultY.shouldRunAgain
        
    case .free(let free):
        //        log("\n y scroll... free")
        let scrollModeResult = handleScrollFree(currentOutput: currentPosition.y,
                                             free: free,
                                             childSize: interactiveLayer.childSize.height,
                                             parentSize: interactiveLayer.parentSize.height)
        currentPosition.y = scrollModeResult.position
        scrollState.yScroll = scrollModeResult.scrollMode
        shouldRunYAgain = scrollModeResult.shouldRunAgain
    } // switch state.yScroll
    
    // HANDLE X AXIS
    
    switch scrollState.xScroll {
        
    case .none:
        //        log("x scroll... .none")
        shouldRunXAgain = false
        
    case .free(let free):
        //        log("x scroll... .free")
        let scrollModeResult = handleScrollFree(currentOutput: currentPosition.x,
                                             free: free,
                                             childSize: interactiveLayer.childSize.width,
                                             parentSize: interactiveLayer.parentSize.width)
        
        currentPosition.x = scrollModeResult.position
        scrollState.xScroll = scrollModeResult.scrollMode
        shouldRunXAgain = scrollModeResult.shouldRunAgain
        
    case .paging(let paging):
        let pagingResultX = handlePaging(currentOutput: currentPosition.x,
                                         paging: paging,
                                         childSize: interactiveLayer.childSize.width,
                                         parentSize: interactiveLayer.parentSize.width,
                                         previousDragPosition: scrollState.lastDragStartingPoint?.x,
                                         velocityAtIndex: interactiveLayer.dragVelocity.width,
                                         pageSize: pageSize.width,
                                         pagePadding: pagePadding.width,
                                         hadJump: hadJumpX,
                                         isDisabledScrollMode: isDisabledScrollModeX)
        
        currentPosition.x = pagingResultX.position
        scrollState.xScroll = pagingResultX.scrollMode
        shouldRunXAgain = pagingResultX.shouldRunAgain
        
        // NOTE: we don't need to set `paging` back in the scrollState,
        // since paging animation state doesn't change.
        
    } // switch state.xScroll
    
    // FINALIZING THE EVAL
    
    if hadJumpY {
        shouldRunYAgain = true
    }
    
    if hadJumpX {
        shouldRunXAgain = true
    }
    
    scrollState.lastDragStartingPoint = interactiveLayer.dragStartingPoint
    
    if !shouldRunXAgain && !shouldRunYAgain {
        //        log("totalScrollInteractionEvalOp: both should run x and should run y were false, so will end entire animation")
        scrollState.reset()
        return .init(outputs: [.position(currentPosition)],
                     willRunAgain: false)
    } else {
        //        #if DEV_DEBUG
        //        log("totalScrollInteractionEvalOp: WILL RUN ENTIRE ANIMATION AGAIN")
        //        #endif
        return .init(outputs: [.position(currentPosition)],
                     willRunAgain: true)
    }
}

func freeScrollDimensionMomentumOp(_ state: FreeScrollDimensionMomentum) -> (FreeScrollDimensionMomentum, CGFloat) {
    //    log("freeScrollDimensionMomentumOp: state: \(state)")
    var state = state
    state.delta = state.amplitude / FREE_SCROLL_MOMENTUM_TIME_CONSTANT
    state.amplitude -= state.delta
    return (state, state.delta)
}

func _handleYJumpPulseReceived(state: ScrollInteractionState,
                               jumpStyleY: ScrollJumpStyle,
                               currentOutput: Double,
                               scrollJumpPositionY: Double,
                               childSize: Double,
                               parentSize: Double
) -> ScrollModeDimensionResult {

    // Use .paging when jump animation style = animated,
    // else .free

    // Create brand new free scroll dimension momentum state;
    // usually created via `startFreeScrollDimensionMomentum`,
    // which sets shouldRun and initial amplitude based on velocity;
    // ... but for jump, we don't actually use the momentum;
    // we just want the `FreeScrollDimensionMomentum` for the FRAME COUNT tracking.
    switch jumpStyleY {

    case .instant:
        //        log("had instant jump y")

        return _handleYInstantJump(
            state: state,
            scrollJumpPositionY: scrollJumpPositionY,
            childSize: childSize,
            parentSize: parentSize)

    case .animated:
        //        log("had animated jump y")

        // we treat an animated jump like a paging animation,
        // where our start point is the pre-jump location,
        // and the end point is the jump location.
        let yScrollMode = ScrollModeState.paging(PagingDimensionState(
                                    start: currentOutput,
                                    end: scrollJumpPositionY,
                                    frame: 0, // always 0
                                    // apparently ALWAYS parenth size ?
                                    distance: parentSize,
                                    isJumpAnimation: true))

        return .init(
            position: currentOutput,
            scrollMode: yScrollMode,
            shouldRunAgain: true
        )
    } // switch jumpStyleY
}

func _handleYInstantJump(state: ScrollInteractionState,
                         scrollJumpPositionY: Double,
                         childSize: Double,
                         parentSize: Double) -> ScrollModeDimensionResult {

    let (updatedOutput,
         shouldRubberband) = runFreeRubberbanding(
            currentOutput: scrollJumpPositionY, // jump position
            frame: 0, // always 0
            childSize: childSize,
            parentSize: parentSize)
    
    let yScrollMode = ScrollModeState.free(FreeScrollDimensionMomentum())

    return .init(
        position: updatedOutput,
        scrollMode: yScrollMode,
        shouldRunAgain: shouldRubberband
    )
}

func _handleXJumpPulseReceived(state: ScrollInteractionState,
                               jumpStyleX: ScrollJumpStyle,
                               currentOutput: Double,
                               scrollJumpPositionX: Double,
                               childSize: Double,
                               parentSize: Double) -> ScrollModeDimensionResult {

    switch jumpStyleX {

    case .instant:
        //        log("had instant jump x")
        return _handleXInstantJump(
            state: state,
            scrollJumpPositionX: scrollJumpPositionX,
            childSize: childSize,
            parentSize: parentSize)

    case .animated:
        //        log("had animated jump x")

        let xScroll = ScrollModeState.paging(PagingDimensionState(
            start: currentOutput,
            end: scrollJumpPositionX,
            frame: 0,
            distance: parentSize,
            isJumpAnimation: true))

        return .init(
            position: currentOutput,
            scrollMode: xScroll,
            shouldRunAgain: true
        )
    } // switch jumpStyleY
}

func _handleXInstantJump(state: ScrollInteractionState,
                         scrollJumpPositionX: Double,
                         childSize: Double,
                         parentSize: Double) -> ScrollModeDimensionResult {

    let (updatedOutput,
         shouldRubberband) = runFreeRubberbanding(
            currentOutput: scrollJumpPositionX, // jump position
            frame: 0, // always 0
            childSize: childSize,
            parentSize: parentSize)

    let xScroll = ScrollModeState.free(FreeScrollDimensionMomentum())
    
    return .init(
        position: updatedOutput,
        scrollMode: xScroll,
        shouldRunAgain: shouldRubberband
    )
}

/// Result of some scroll eval change for a given dimension (x or y).
struct ScrollModeDimensionResult {
    let position: Double
    var scrollMode: ScrollModeState
    var shouldRunAgain: Bool
}

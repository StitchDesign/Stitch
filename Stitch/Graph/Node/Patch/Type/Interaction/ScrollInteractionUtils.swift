//
//  ScrollInteractionUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/14/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct ScrollNodeInputLocations {
    // The specific assigned layer (LayerNodeId)
    static let layerIndex = 0

    static let xScrollMode = 1
    static let yScrollMode = 2

    static let contentSize = 3
    static let directionLocking = 4

    static let pageSize = 5
    static let pagePadding = 6

    static let jumpStyleX = 7
    static let jumpToX = 8
    static let jumpPositionX = 9

    static let jumpStyleY = 10
    static let jumpToY = 11
    static let jumpPositionY = 12

    static let decelerationRate = 13

    static let layerPosition = 14
}

struct ScrollNodeVersioning {
    static let v14InputCount = 3
    static let v15InputCount = 14
}

extension PortValues {
    private func _scrollNodeInputSizeHelper<T>(_ location: Int,
                                               _ getter: (PortValue) -> T?) -> T? {
        self[safeIndex: location].flatMap(getter)
    }

    var scrollContentSize: LayerSize? {
        _scrollNodeInputSizeHelper(ScrollNodeInputLocations.contentSize,
                                   \PortValue.getSize)
    }

    var scrollDirectionLocking: Bool? {
        _scrollNodeInputSizeHelper(ScrollNodeInputLocations.directionLocking,
                                   \PortValue.getBool)
    }

    // paging
    var scrollPageSize: LayerSize? {
        _scrollNodeInputSizeHelper(ScrollNodeInputLocations.pageSize,
                                   \PortValue.getSize)
    }
    var scrollPagePadding: LayerSize? {
        _scrollNodeInputSizeHelper(ScrollNodeInputLocations.pagePadding,
                                   \PortValue.getSize)
    }

    // jumping to x
    var scrollJumpStyleX: ScrollJumpStyle? {
        _scrollNodeInputSizeHelper(ScrollNodeInputLocations.jumpStyleX,
                                   \PortValue.getScrollJumpStyle)
    }
    var scrollJumpToX: TimeInterval? {
        _scrollNodeInputSizeHelper(ScrollNodeInputLocations.jumpToX,
                                   \PortValue.getPulse)
    }
    var scrollJumpPositionX: Double? {
        _scrollNodeInputSizeHelper(ScrollNodeInputLocations.jumpPositionX,
                                   \PortValue.getNumber)
    }

    // jumping to y
    var scrollJumpStyleY: ScrollJumpStyle? {
        _scrollNodeInputSizeHelper(ScrollNodeInputLocations.jumpStyleY,
                                   \PortValue.getScrollJumpStyle)
    }
    var scrollJumpToY: TimeInterval? {
        _scrollNodeInputSizeHelper(ScrollNodeInputLocations.jumpToY,
                                   \PortValue.getPulse)
    }
    var scrollJumpPositionY: Double? {
        _scrollNodeInputSizeHelper(ScrollNodeInputLocations.jumpPositionY,
                                   \PortValue.getNumber)
    }

    // deceleration
    var scrollDecelerationRate: ScrollDecelerationRate? {
        _scrollNodeInputSizeHelper(ScrollNodeInputLocations.decelerationRate,
                                   \PortValue.getScrollDecelerationRate)
    }
}

enum RubberBandingDirection: String {
    case neg, pos, none
}

enum ScrollDirectionLocking: String, Codable, Hashable {
    case vertical, horizontal, none
}

let scrollChoices = [
    ScrollMode.free.rawValue,
    ScrollMode.paging.rawValue,
    ScrollMode.disabled.rawValue
]

let scrollModePorts = [
    ScrollNodeInputLocations.xScrollMode,
    ScrollNodeInputLocations.yScrollMode
]

// Can reuse inside the actual freeScroll op eval ?
func calcRubberBandingDirection(childSize: Double,
                                childPosition: Double,
                                parentSize: Double) -> RubberBandingDirection {

    //    log("calcRubberBandingDirection: childSize: \(childSize)")
    //    log("calcRubberBandingDirection: childPosition: \(childPosition)")
    //    log("calcRubberBandingDirection: parentSize: \(parentSize)")

    // okay for when a smaller-than-parent child has been dragged down and needs to rubberband;
    // might need to change for when small-child has been dragged up?
    if childPosition > 0 {
        //        log("calcRubberBandingDirection: neg")
        return .neg
    }
    // what is child ie layer position when we have momentum involved?
    // it's just the child position at that momentum?

    // Only valid when childSize > parentSize;
    // else if (childPosition + childSize < parentSize) {
    else if (childSize > parentSize) && (childPosition + childSize < parentSize) {
        //        log("child > parent: calcRubberBandingDirection: pos")
        return .pos
    }

    // i.e. we dragged the layer upward (so pos<0), but the layer is smaller than the parent
    else if (childSize <= parentSize) && childPosition < 0 {
        //        log("child <= parent: calcRubberBandingDirection: pos")
        return .pos
    }

    // just a default
    else {
        // When the size exceeds the parent bounds but the view hasn't scroll
        // off screen
        //        log("calcRubberBandingDirection: default")
        return .none
    }
}

// ie we were pulling the view down, and so had distance at top;
// we thus want the child's top to go back to the parent's top, or
// ie we were pulling the view up, and so had distance at the bottom;
// thus we want child's bottom to align with parent's bottom

// combine this with `calcRubberbandingDirection` ?
func getRubberBandingEndPosition(parentSize: Double,
                                 childSize: Double,
                                 childPosition: Double,
                                 rubberBanding: RubberBandingDirection) -> Double {
    switch rubberBanding {
    case .neg:
        //        log("getRubberBandingEndPosition: .neg")
        return .zero
    case .pos:
        if childSize <= parentSize {
            //            log("getRubberBandingEndPosition: .pos: child <= parent")
            return .zero
        } else {
            //            log("getRubberBandingEndPosition: .pos: child > parent")
            return parentSize - childSize
        }
    case .none:
        //        log("getRubberBandingEndPosition: .none")
        return childPosition
    }
}

/// Calculates end position on page scroll for a single axis.
func calcScrollPagingPosition(childPosition: Double,
                              childSize: Double,
                              previousDragPosition: Double,
                              parentSize: Double,
                              velocity: CGFloat,
                              pageSize: CGFloat,
                              pagePadding: CGFloat? = nil) -> Double {
    
    guard childSize > parentSize else {
        log("calcScrollPagingPosition: child not larger than parent")
        return childPosition
    }

    // If manual page size not provided, default to half parent size.
    // Always include page padding.
//    let page = (pageSize ?? (parentSize/2)) + (pagePadding ?? 0)

    // Max number of pages that could exist given scroll view's size
    // TODO: ignores page-padding ?
    let maxIndex = getMaxPagingIndex(child: childSize,
                                     parent: parentSize,
                                     pageSize: pageSize)

    guard maxIndex > 0 else {
        log("calcScrollPagingPosition: only one resting position")
        return 0.0
    }

    let restingPositions = _restingPositions(
        maxIndex: maxIndex,
        page: pageSize)

    // Find first index which exceeds current position, subtract by 1 to go back to previous resting point
    let currentPageIndex = (restingPositions
        .firstIndex { childPosition > $0 } ?? maxIndex + 1) - 1

    // If drag gesture hasn't panned enough, return to current page index
    let pageMovement = pageMovement(velocity: velocity,
                                    prevDragPosition: previousDragPosition,
                                    newDragPosition: childPosition,
                                    pageSize: pageSize)

    // Index needs to be contained or else the view will page off screen
    let nextPageIndex = pageMovement.calculateIndex(current: currentPageIndex,
                                                    maxIndex: maxIndex)

    // ASSUMES: childSize > parentSize
    let newEndPosition = (Double(nextPageIndex) * -pageSize).asPositiveZero

    return newEndPosition
}

let FLICK_PAGING_VELOCITY_THRESHOLD: CGFloat = 200
let DRAG_PAGING_THRESHOLD = 30

enum PageDelta {
    case movePrev
    case moveNext
    case none
}

extension PageDelta {
    func calculateIndex(current: Int,
                        maxIndex: Int) -> Int {
        switch self {
        case .movePrev:
            return max(0, current - 1)
        case .moveNext:
            return min(maxIndex, current + 1)
        case .none:
            return current
        }
    }
}

func pageMovement(velocity: CGFloat,
               prevDragPosition: Double,
               newDragPosition: Double,
                  pageSize: Double) -> PageDelta {
    
    let dragThreshold = min(Double(DRAG_PAGING_THRESHOLD), pageSize)

    // if manual page size is not provided,
    // default to parent size as page size
    //    log("willPage: page: \(page)")

    // We must move at least `(page/2) + page padding`,
    // i.e. the whole page padding gets added,
    // i.e. NOT `(page + page padding) / 2`

    //    let minPagingDistance = (page / 2) + (pagePadding ?? 0)
//    let dragged = abs(dragPosition - childPosition)
    let flickedHardEnough = velocity.magnitude > FLICK_PAGING_VELOCITY_THRESHOLD
    let draggedHardEnough = dragThreshold < abs(newDragPosition - prevDragPosition)
    
    guard flickedHardEnough || draggedHardEnough else {
        return .none
    }

    //    log("willPage: minPagingDistance: \(minPagingDistance)")
    //    log("willPage: dragged: \(dragged)")
    //    log("willPage: draggedFarEnough: \(draggedFarEnough)")
    //    log("willPage: flickedHardEnough: \(flickedHardEnough)")

    return prevDragPosition < newDragPosition ? .movePrev : .moveNext
}

// Given the max index
func _restingPositions(maxIndex: Int,
                       // assumes page size + page pading
                       page: Double) -> [Double] {
    (0...maxIndex).map {
        Double($0) * -page
    }
}

// TODO: for max index, we ignore page padding ?
func getMaxPagingIndex(child: Double,
                      parent: Double,
                      pageSize: CGFloat?) -> Int {

    // If manual page size not provided,
    // default to parent/2.
    // TODO: for maxIndex, do we ignore pagePadding?
    let page: Double = pageSize ?? zeroCompatibleDivision(numerator: parent,
                                                          denominator: 2)

    return Int(zeroCompatibleDivision(numerator: parent,
                                              denominator: page)) + 2
}

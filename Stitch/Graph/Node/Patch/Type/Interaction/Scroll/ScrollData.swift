//
//  ScrollData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/24/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

final class ScrollInteractionState: NodeEphemeralObservable {
    var xScroll: ScrollModeState = .none
    var yScroll: ScrollModeState = .none
    
    var scrollDirectionLocked: ScrollDirectionLocking = .none
    
    // Tracks last known drag point for paging purposes
    var lastDragStartingPoint: CGPoint?
}

extension ScrollInteractionState {
    func onPrototypeRestart(document: StitchDocumentViewModel) {
        self.lastDragStartingPoint = nil
        self.reset()
    }
    
    func reset() {
        self.xScroll = .none
        self.yScroll = .none
        self.scrollDirectionLocked = .none
    }
}

enum ScrollModeState: Equatable, Hashable {
    case none, // scrollMode = disabled
         paging(PagingDimensionState), // scrollMode = .paging
         //         free(FreeScrollState) // scrollMode = .free
         free(FreeScrollDimensionMomentum) // scrollMode = .free

    var incrementFrame: ScrollModeState {
        switch self {
        case .none:
            return self
        case .paging(let pagingDimensionState):
            return .paging(pagingDimensionState.incrementFrame)
        case .free(let freeScrollDimensionMomentum):
            return .free(freeScrollDimensionMomentum.incrementFrame)
        }
    }
}

extension ScrollInteractionState {
    func initializeScrollMode(_ scrollPath: ReferenceWritableKeyPath<ScrollInteractionState, ScrollModeState>,
                              from scrollMode: ScrollMode) {
        switch scrollMode {
        case .disabled:
            self[keyPath: scrollPath] = .none
        case .free:
            self[keyPath: scrollPath] = .free(.init())
        case .paging:
            self[keyPath: scrollPath] = .paging(.init())
        }
    }
}

struct FreeScrollDimensionMomentum: Equatable, Hashable {
    var amplitude: CGFloat = .zero
    var delta: CGFloat = .zero

    var frame: CGFloat = .zero

    /*
     Set `true` in onDragEnded when velocity large enough.
     Set `false` when we:
     (1) have reached the max number of momentum steps in node eval,
     (2) reset momentum in onPreviewLayerDrag
     */
    var shouldRun = false

    var incrementFrame: FreeScrollDimensionMomentum {
        var _s = self
        _s.frame += 1
        return _s
    }
}

// like `ScrollAnimationState`,
// but for a single dimension instead of both.
struct PagingDimensionState: Equatable, Hashable {
    var start: CGFloat = .zero // startValue
    var end: CGFloat = .zero // toValue

    var frame: CGFloat = .zero // frameCount

    var distance: CGFloat = .zero

    // TODO: create a separate abstraction?
    // We re-use PagingDimensionState for animating to a jump location.
    // After the jump, we may need to rubberband down or up;
    // we use this as a flag to indicate that, in this case, "pseudo-paging" and rubberbanding can coexist.

    // NOTE: the current, regular logic of paging makes rubberbanding and paging exclusive:
    // EITHER we successfully paged to a new location from which we will not need to rubberband,
    // OR we did not page and thus may need to rubberband.
    var isJumpAnimation: Bool = false

    var incrementFrame: PagingDimensionState {
        var _s = self
        _s.frame += 1
        return _s
    }
}

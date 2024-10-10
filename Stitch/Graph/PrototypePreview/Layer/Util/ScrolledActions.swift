//
//  ScrolledActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/5/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit


// only called for specific axis
func preparePagingDimensionState(parentLength: CGFloat, // width or height
                                 childLength: CGFloat, // width or height
                                 childLocation: CGFloat,
                                 previousDragLocation: CGFloat,
                                 velocityAtIndex: CGFloat,
                                 pageSize: CGFloat,
                                 pagePadding: CGFloat? = nil) -> PagingDimensionState {

    let newEndPosition = calcScrollPagingPosition(
        childPosition: childLocation,
        childSize: childLength,
        previousDragPosition: previousDragLocation,
        parentSize: parentLength,
        velocity: velocityAtIndex,
        pageSize: pageSize,
        pagePadding: pagePadding)

    return PagingDimensionState(
        start: childLocation,
        end: newEndPosition,
        frame: 0,
        distance: parentLength)
}

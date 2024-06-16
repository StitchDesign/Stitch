//
//  CommentBoxHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/6/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension CGFloat {
    static let commentBoxMinimumWidth: CGFloat = 300
    static let commentBoxMinimumHeight: CGFloat = 200
    static let commentBoxCornerRadius: CGFloat = 25.0
}

// DEBUG

//// let commentBoxTitle = "Love is a very long message to communicate in just a few words"
//
// let commentBoxTitle = "Love is a very long message to communicate in just a few words and there's even more to say, but will the comment box be long enough to see what's beneath?"
//
//// let commentBoxTitle = "Your comment here"

let commentBoxColor = Color.blue

extension CGSize {
    static let commentBoxMinimumSize = CGSize(
        width: .commentBoxMinimumWidth,
        height: .commentBoxMinimumHeight)
}

// -- MARK: COMMENT BOX TRIG CALC

// returns (new box size, new expansion direction, new anchor point)
func commentBoxTrigCalc(start: CGPoint,
                        end: CGPoint,
                        previousSize: CGSize,
                        translation: CGSize,
                        existingExpansionDirection: ExpansionDirection?,
                        existingAnchorPoint: CGPoint,
                        previousPosition: CGPoint) -> (CGSize, ExpansionDirection, CGPoint) {

    // log("commentBoxTrigCalc called")

    var translationX = translation.width
    var translationY = translation.height

    var newExpansionDirection: ExpansionDirection

    var newAnchorPoint: CGPoint

    // Is end point left of start point?
    let left = isLeftOf(start, end)
    let right = !left && end != .zero

    // Is end point above start point?
    let above = isAbove(start, end)
    let below = !above && end != .zero

    // To know which direction out from which we should expand the box,
    // compare box's start vs end (i.e. current position of user's cursor).
    if left && above {
        newExpansionDirection = .topLeft
    } else if left && below {
        newExpansionDirection = .bottomLeft
    } else if right && above {
        newExpansionDirection = .topRight
    } else if right && below {
        newExpansionDirection = .bottomRight
    } else {
        // probably not correct?
        // what about when we ONLY translation rightward, but not up or down?
        print("... none")
        return (.zero, .none, existingAnchorPoint)
    }

    // if we ALREADY had an expansion direction, then ignore the new one
    if let existingExpansionDirection = existingExpansionDirection {
        print("trigCalc: reusing existingExpansionDirection \(existingExpansionDirection)")
        newExpansionDirection = existingExpansionDirection
    }

    switch newExpansionDirection {
    case .topLeft:

        // `expansion direction: .topLeft` means:
        // translations up (-y) and left (-x) grow the box,
        // translations down (+y) and right (+x) shrink the box.

        if translationY < 0 {
            print("topLeft: grow y")
            translationY = translationY.magnitude // add to box size
        } else if translationY > 0 {
            print("topLeft: shrink y")
            translationY = -translationY // remove from box size
        }

        if translationX < 0 {
            print("topLeft: grow x")
            translationX = translationX.magnitude // add to box size
        } else if translationX > 0 {
            print("topLeft: shrink x")
            translationX = -translationX // remove from box size
        }

    case .topRight:
        // `expansion direction: .topRight` means:
        // translations up and right grow the box,
        // translations down and left shrink the box.

        if translationY < 0 {
            translationY = translationY.magnitude // add to box size
        } else if translationY > 0 {
            translationY = -translationY // remove from box size
        }

        if translationX < 0 {
            // Already negative, so will already shrink box
            //            translationX = -translationX // remove from box size
        } else if translationX > 0 {
            translationX = translationX.magnitude // add to box size
        }

    case .bottomLeft:
        // `expansion direction: .bottomLeft` means:
        // translations down and left grow the box,
        // translations up and right shrink the box.

        if translationY < 0 {
            // Already negaive, so will already shrink the box
            //            translationY = -translationY // remove from box size
        } else if translationY > 0 {
            translationY = translationY.magnitude // add to box size
        }

        if translationX < 0 {
            translationX = translationX.magnitude // add to box size
        } else if translationX > 0 {
            translationX = -translationX // remove from box size
        }

    case .bottomRight:
        // `expansion direction: .bottomRight` means:
        // translations down and right grow the box,
        // translations up and left shrink the box.
        if translationY < 0 {
            print("bottomRight: shrink y")
            // translation already negative, so will already shrink the box
            //            translationY = -translationY // remove from box size
        } else if translationY > 0 {
            print("bottomRight: grow y")
            translationY = translationY.magnitude // add to box size
        }

        if translationX < 0 {
            print("bottomRight: shrink x")
            //            translationX = -translationX // remove from box size
            // translation x already negative, so adding to width will already shrink
        } else if translationX > 0 {
            print("bottomRight: grow x")
            translationX = translationX.magnitude // add to box size
        }

    case .none:
        print("none...")
    }

    var newWidth = previousSize.width + translationX
    var newHeight = previousSize.height + translationY

    // Apply the translation also to the anchor point
    newAnchorPoint = previousPosition

    // Use *non-size-adjusted* translation
    newAnchorPoint.x = previousPosition.x + translation.width/2
    newAnchorPoint.y = previousPosition.y + translation.height/2

    if newWidth.magnitude < .commentBoxMinimumWidth {
        newWidth = .commentBoxMinimumWidth
    }
    if newHeight.magnitude < .commentBoxMinimumHeight {
        newHeight = .commentBoxMinimumHeight
    }

    // Magnitude, because size must always be non-negative
    let newSize = CGSize(width: newWidth.magnitude,
                         height: newHeight.magnitude)

    // log("commentBoxTrigCalc: original translation: \(translation)")
    // log("commentBoxTrigCalc: translationX now: \(translationX)")
    // log("commentBoxTrigCalc: translationY now: \(translationY)")
    // log("commentBoxTrigCalc: start: \(start)")
    // log("commentBoxTrigCalc: end: \(end)")
    // log("commentBoxTrigCalc: existingExpansionDirection: \(existingExpansionDirection)")
    // log("commentBoxTrigCalc: previousSize: \(previousSize)")
    // log("commentBoxTrigCalc: newSize: \(newSize)")
    // log("commentBoxTrigCalc: newExpansionDirection: \(newExpansionDirection)")
    // log("commentBoxTrigCalc: newAnchorPoint: \(newAnchorPoint)")

    return (newSize, newExpansionDirection, newAnchorPoint)
}

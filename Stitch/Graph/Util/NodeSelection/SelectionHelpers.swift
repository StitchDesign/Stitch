//
//  SelectionHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/7/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

func isLeftOf(_ start: CGPoint, _ end: CGPoint) -> Bool {
    return end.x < start.x
}

func isRightOf(_ start: CGPoint, _ end: CGPoint) -> Bool {
    return end.x > start.x
}

func isAbove(_ start: CGPoint, _ end: CGPoint) -> Bool {
    return end.y < start.y
}

func isBelow(_ start: CGPoint, _ end: CGPoint) -> Bool {
    return end.y > start.y
}

func CGPointDistanceSquared(from: CGPoint, to: CGPoint) -> CGFloat {
    (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
}

//  https://swiftui-lab.com/trigonometric-recipes-for-swiftui/
// start = drag starting location
// end = drag current location
// func trigCalc(start: CGPoint, end: CGPoint) -> CGSize {
func trigCalc(start: CGPoint, end: CGPoint) -> (CGSize, ExpansionDirection) {

    let newWidth = end.x - start.x
    let newHeight = end.y - start.y

    //    log("newWidth: \(newWidth)")
    //    log("newHeight: \(newHeight)")

    let newSize = CGSize(width: abs(newWidth),
                         height: abs(newHeight))

    if isLeftOf(start, end) && isAbove(start, end) {
        //        log("left and above")
        return (newSize, .topLeft)
    } else if isLeftOf(start, end) && isBelow(start, end) {
        //        log("left and below")
        return (newSize, .bottomLeft)
    } else if isRightOf(start, end) && isAbove(start, end) {
        //        log("right and above")
        return (newSize, .topRight)
    } else if isRightOf(start, end) && isBelow(start, end) {
        //        log("right and below")
        return (newSize, .bottomRight)
    } else {
        //        log("... none")
        return (.zero, .none)
    }
}

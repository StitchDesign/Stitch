//
//  GraphDraggablePosition.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/25/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct GraphOriginAtStart: Equatable, Hashable {
    let origin: CGPoint

    // origins set by momentum can be overwritten
    let setByMomentum: Bool
}

// Draggable positions require a `current` and `previous` location,
// per how SwiftUI DragGesture's translation works.
extension GraphMovementObserver {
    // Returns "final X position, such
    // note: the position itself, not the
    func capMomentumPositionX(graphBounds: CGRect,
                              frame: CGRect,
                              zoom: CGFloat,
                              startOrigins: CGPoint) -> CGFloat? {

        // where eastern edge of blue nodes box was at when gesture started
        let easternNodeAtStart = startOrigins.x + graphBounds.size.width.magnitude/2 + self.localPreviousPosition.x

        // where eastern edge of blue nodes box is currently at
        let easternNode = graphBounds.origin.x + graphBounds.size.width.magnitude/2 + self.localPosition.x

        // where western edge of blue nodes box is currently at
        let westernNode = graphBounds.origin.x - graphBounds.size.width.magnitude/2 + self.localPosition.x

        // where western edge of blue nodes box was at when gesture started
        let westernNodeAtStart = startOrigins.x - graphBounds.size.width.magnitude/2 + self.localPreviousPosition.x

        let westernBorder = 0.0
        let easternBorder = frame.width

        let maxWestwardTranslation = -(easternNodeAtStart.magnitude)

        let maxEastwardTranslation = abs(easternBorder - westernNodeAtStart)

        // Is the eastern node at or past the western border?
        let eastNodePastWestBorder = easternNode <= westernBorder

        let westNodePastEastBorder = westernNode >= easternBorder

        // If we've indeed hit the western border,
        // then localPosition is the max farthest west we can go, so just return that
        if eastNodePastWestBorder {
            // have to move this elsewhere? do east vs west border statements conflict ?

            // TODO: handle this rare bug case where, when scale < 1,
            // we can somehow start with the eastern node to the west of the west-border already.
            //        if easternNodeAtStart < 0 {
            if easternNodeAtStart < westernBorder {
                //            log("capMomentumPositionX: eastern node STARTED west of western border; returning nil")
                return nil
            }

            // ie the max westward translation (from vs the beginning of the momentum movement)

            // We have to scale the translation the same way we do in `updatePosition`,
            // since we're calculating a final position here.
            let finalX = self.localPreviousPosition.x + (maxWestwardTranslation / zoom)
            return finalX
        }

        if westNodePastEastBorder {
            if westernNodeAtStart > easternBorder {
                return nil
            }

            // how far we can move the graph before the western node hits the eastern border
            let finalX = self.localPreviousPosition.x + (maxEastwardTranslation / zoom)
            return finalX
        }

        return nil
    }

    func capMomentumPositionY(graphBounds: CGRect,
                              frame: CGRect,
                              zoom: CGFloat,
                              startOrigins: CGPoint) -> CGFloat? {

        let southernNodeAtStart = startOrigins.y + graphBounds.height.magnitude/2 + self.localPreviousPosition.y

        // where eastern edge of blue nodes box is currently at
        let southernNode = graphBounds.origin.y + graphBounds.size.height.magnitude/2 + self.localPosition.y

        // where western edge of blue nodes box is currently at
        let northernNode = graphBounds.origin.y - graphBounds.size.height.magnitude/2 + self.localPosition.y

        let northernNodeAtStart = startOrigins.y - graphBounds.size.height.magnitude/2 + self.localPreviousPosition.y

        let northernBorder: CGFloat = 0.0
        let southernBorder: CGFloat = frame.height

        let maxNorthwardTranslation = -(southernNodeAtStart.magnitude)

        // this is equivalent to what what capMomentumPositionX and borderHelperY has:
        let maxSouthwardTranslation = abs(southernBorder - northernNodeAtStart)

        let southNodePastNorthBorder = southernNode <= northernBorder
        let northNodePastSouthBorder = northernNode >= southernBorder

        // If we've indeed hit the western border,
        // then localPosition is the max farthest west we can go, so just return that
        if southNodePastNorthBorder {
            if southernNodeAtStart < northernBorder {
                return nil
            }

            let finalY = self.localPreviousPosition.y + (maxNorthwardTranslation / zoom)
            return finalY
        }

        if northNodePastSouthBorder {
            if northernNodeAtStart > southernBorder {
                return nil
            }

            let finalY = self.localPreviousPosition.y + (maxSouthwardTranslation / zoom)
            return finalY
        }

        return nil
    }
}

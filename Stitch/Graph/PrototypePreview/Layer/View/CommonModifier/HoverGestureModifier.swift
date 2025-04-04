//
//  HoverGestureModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/19/23.
//

import SwiftUI
import StitchSchemaKit

struct HoverGestureModifier: ViewModifier {

    @Bindable var document: StitchDocumentViewModel
    let previewWindowSize: CGSize

    @State var lastDragPosition: CGPoint?
    @State var timeOfLastDragPosition: TimeInterval?

    static let MouseHoverId: PreviewCoordinate = .init(layerNodeId: UUID(), loopIndex: 0)

    func body(content: Content) -> some View {
        content
        // Previously we could rely on the .position of a child layer to expand the space on which .onContinuousHover operated; but now (April 2025) we use .offset, which does not expand the hit area; so we attach a .contentShape manually
            .frame(width: previewWindowSize.width, height: previewWindowSize.height)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {

                case .active(let location):
                    // log("Hover: active: location: \(location)")

                    let now: TimeInterval = Date.now.timeIntervalSince1970

                    if let lastDragPosition = self.lastDragPosition,
                       let timeOfLastDragPosition = self.timeOfLastDragPosition {

                        var xDiff = location.x - lastDragPosition.x
                        var yDiff = location.y - lastDragPosition.y

                        // if we're west of our last location,
                        // then x velocity is negative
                        if location.x < lastDragPosition.x {
                            xDiff = xDiff.magnitude * -1
                        } else {
                            xDiff = xDiff.magnitude
                        }

                        // if we're north of our last location,
                        // then y velocity is negative
                        if location.y < lastDragPosition.y {
                            yDiff = yDiff.magnitude * -1
                        } else {
                            yDiff = yDiff.magnitude
                        }

                        let timeDiff = now - timeOfLastDragPosition

                        let xVelocity = xDiff / timeDiff
                        let yVelocity = yDiff / timeDiff

                        // Have to dampen?
                        let dampenedXVelocity = xVelocity / 10
                        let dampenedYVelocity = yVelocity / 10

                        let velocity = CGPoint(x: dampenedXVelocity,
                                               y: dampenedYVelocity)

                        //                        log("Hover: xDiff: \(xDiff)")
                        //                        log("Hover: yDiff: \(yDiff)")
                        //                        log("Hover: timeDiff: \(timeDiff)")
                        //                        log("Hover: xVelocity: \(xVelocity)")
                        //                        log("Hover: yVelocity: \(yVelocity)")
                        //                        log("Hover: dampenedXVelocity: \(dampenedXVelocity)")
                        //                        log("Hover: dampenedYVelocity: \(dampenedYVelocity)")
                        //                        log("Hover: active: location: \(location)")
                        document.layerHovered(location: location,
                                              velocity: velocity)
                    }

                    self.lastDragPosition = location
                    self.timeOfLastDragPosition = now

                case .ended:
                    // log("Hover: ended")
                    self.lastDragPosition = nil
                    self.timeOfLastDragPosition = nil

                    document.layerHoverEnded()
                }

            } // .onContinuousHover
    }
}

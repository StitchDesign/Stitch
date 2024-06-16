//
//  HoverGestureModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/19/23.
//

import SwiftUI
import StitchSchemaKit

struct HoverGestureModifier: ViewModifier {

    @Bindable var graph: GraphState
    let previewWindowSize: CGSize

    @State var lastDragPosition: CGPoint?
    @State var timeOfLastDragPosition: TimeInterval?

    static let MouseHoverId: PreviewCoordinate = .init(layerNodeId: UUID(), loopIndex: 0)

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {

                case .active(let location):
                    //                    #if DEV_DEBUG
                    //                    log("Hover: active: location: \(location)")
                    //                    #endif

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

                        //                        #if DEV_DEBUG
                        //                        log("Hover: xDiff: \(xDiff)")
                        //                        log("Hover: yDiff: \(yDiff)")
                        //                        log("Hover: timeDiff: \(timeDiff)")
                        //                        log("Hover: xVelocity: \(xVelocity)")
                        //                        log("Hover: yVelocity: \(yVelocity)")
                        //                        log("Hover: dampenedXVelocity: \(dampenedXVelocity)")
                        //                        log("Hover: dampenedYVelocity: \(dampenedYVelocity)")
                        //                        log("Hover: active: location: \(location)")
                        //                        #endif
                        dispatch(LayerHovered(location: location,
                                              velocity: velocity))
                    }

                    self.lastDragPosition = location
                    self.timeOfLastDragPosition = now

                case .ended:
                    //                    #if DEV_DEBUG
                    //                    log("Hover: ended")
                    //                    #endif
                    self.lastDragPosition = nil
                    self.timeOfLastDragPosition = nil

                    dispatch(LayerHoverEnded())
                }

            } // .onContinuousHover
    }
}

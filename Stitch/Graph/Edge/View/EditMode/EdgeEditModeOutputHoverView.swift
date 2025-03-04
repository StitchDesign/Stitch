//
//  EdgeEditModeOutputHoverView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/1/24.
//

import StitchSchemaKit
import SwiftUI

extension Double {
    static let EDGE_EDIT_MODE_NODE_UI_ELEMENT_ANIMATION_LENGTH = 0.2
}

struct EdgeEditModeOutputHoverViewModifier: ViewModifier {

    @Bindable var graph: GraphState
    let document: StitchDocumentViewModel
    let outputCoordinate: OutputPortViewData
    
    var isDraggingOutput: Bool {
        graph.edgeDrawingObserver.drawingGesture.isDefined
    }

    static let REQUIRED_HOVER_DURATION: CGFloat = 0.75

    // Whether overlay-ui is shown; always instant, no min duration
    @State var hovered: Bool = false

    // Tracks the "min hover duration before we show labels in front of nearby-node's inputs"
    @State var hoverStartTime: TimeInterval?

    func body(content: Content) -> some View {
        content
            .overlay {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: 8.0,
                                                          bottomLeading: 8.0,
                                                          bottomTrailing: 0,
                                                          topTrailing: 0),
                                       style: .continuous)
                    // light mode: 10% darker
                    // dark mode: 10% lighter
                    .fill(STITCH_EDIT_BUTTON_COLOR.opacity(0.1))
                    .padding([.leading, .top, .bottom], -8)
                    .allowsHitTesting(false)
                    .opacity((hovered && !isDraggingOutput) ? 1 : 0)
                    .animation(.linear(duration: .EDGE_EDIT_MODE_NODE_UI_ELEMENT_ANIMATION_LENGTH),
                               value: isDraggingOutput)
                    .animation(.linear(duration: .EDGE_EDIT_MODE_NODE_UI_ELEMENT_ANIMATION_LENGTH),
                               value: hovered)

            }

            .onHover { isHovering in
                // Make sure the graph isn't in movement
                guard !graph.graphMovement.graphIsDragged,
                      !graph.graphMovement.canvasItemIsDragged else {
                    log("EdgeEditModeOutputHoverViewModifier: graph is in movement; doing nothing")
                    return
                }

                guard !isDraggingOutput else {
                    // if we're dragging the output, turn off hover-overlay, exit edge-edit-mode etc.
                    self.hovered = false
                    self.hoverStartTime = nil
                    dispatch(OutputHoverEnded())
                    return
                }

                self.hovered = isHovering // immediately show overlay

                guard isHovering else {
                    // if we're not hovering, do not check min-hover-duration etc.
                    self.hoverStartTime = nil
                    dispatch(OutputHoverEnded())
                    return
                }

                // immediately enable edge-edit mode
                graph.outputHovered(outputCoordinate: outputCoordinate,
                                    groupNodeFocused: document.groupNodeFocused?.groupNodeId)

                if !self.hoverStartTime.isDefined {
                    self.hoverStartTime = Date.now.timeIntervalSince1970
                }

                // if we're still hovering 0.75 seconds after the hover has started,
                // then we show the labels in front of the nearby node's inputs.
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.REQUIRED_HOVER_DURATION) {

                    if let hoverStartTime = self.hoverStartTime,
                       !isDraggingOutput {

                        let now = Date.now.timeIntervalSince1970
                        let diff = now - hoverStartTime

                        //                        log("hoverStartTime: \(hoverStartTime)")
                        //                        log("now: \(now)")
                        //                        log("diff: \(diff)")

                        if diff > Self.REQUIRED_HOVER_DURATION {
                            dispatch(OutputHoveredLongEnough())
                        }
                    }
                }
            }
    }
}

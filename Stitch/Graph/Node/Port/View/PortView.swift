//
//  PortView.swift
//  prototype
//
//  Created by cjc on 1/21/21.
//

import SwiftUI
import StitchSchemaKit

let EXTENDED_HITBOX_WIDTH: CGFloat = 32 // 68 // 48 // 40 // 32
let EXTENDED_HITBOX_HEIGHT: CGFloat = 24

let PORT_ENTRY_NON_EXTENDED_HITBOX_SIZE = CGSize(
    width: PORT_VISIBLE_LENGTH,
    height: NODE_ROW_HEIGHT)

struct PortEntryView: View {
    @Environment(\.appTheme) var theme

    static let height: CGFloat = 8

    @Bindable var rowObserver: NodeRowObserver
    @Bindable var graph: GraphState
    let coordinate: PortViewType
    let color: PortColor
    
    // Specify the node delegate (rather than using default one in row observer)
    // in event of port for group
    let nodeDelegate: NodeDelegate?

    @MainActor
    var portColor: Color {
        rowObserver.portColor.color(theme)
    }
    
    @MainActor
    var isNodeMoving: Bool {
        self.nodeDelegate?.isNodeMoving ?? false
    }
    
    @MainActor
    var isDraggingFromThisOutput: Bool {
        // Only applies if output drag exists and on this port
        guard let outputOnDrag = graph.edgeDrawingObserver.drawingGesture?.output else {
            return false
        }
        
        return outputOnDrag.outputPortViewData == coordinate.output
    }
    
    // Only animate port colors if we're dragging from this output
    @MainActor
    var animationTime: Double {
        isDraggingFromThisOutput ? DrawnEdge.animationDuration : .zero
    }
    
    var body: some View {
        
        let hasEdge = rowObserver.hasEdge
        
        // TODO: revisit empty port color after node body color has changed
//        let portBodyColor = hasEdge ? portColor : NodeUIColor.patchNode.body.opacity(0.05)
        
        ZStack {
            Rectangle().fill(portColor)
//            Rectangle().fill(portBodyColor)
//                .overlay {
//                    if !hasEdge {
//                        let color = STITCH_TITLE_FONT_COLOR.opacity(0.5)  // Color(.sheetBackground).opacity(0.5)
//                        Circle().fill(color)
//                            .frame(width: 4, height: 4)
//                            .offset(x: coordinate.isInput ? 2 : -2)
//                    }
//                }
                .frame(PORT_ENTRY_NON_EXTENDED_HITBOX_SIZE)
            // TODO: use `UnevenRoundedRectangle` ?
                .clipShape(RoundedRectangle(cornerRadius: CANVAS_ITEM_CORNER_RADIUS))
                .background {
                    Rectangle()
                        .fill(portColor)
//                        .fill(portBodyColor)
                        .frame(width: Self.height)
                        .offset(x: coordinate.isInput ? -4 : 4)
                }
                .background {
                    GeometryReader { geometry in
                        let origin = geometry.frame(in: .named(NodesView.coordinateNameSpace)).origin
                        
                        Color.clear
                            .onChange(of: graph.groupNodeFocused) {
                                self.updatePortViewData(newOrigin: origin)
                            }
                            .onChange(of: origin,
                                      initial: true) { _, newOrigin in
                                self.updatePortViewData(newOrigin: newOrigin)
                            }
                    }
                }
        }
        .overlay(PortEntryExtendedHitBox(rowObserver: rowObserver,
                                         coordinate: coordinate))
        .animation(.linear(duration: self.animationTime),
                   value: portColor)
        // Update port color on selected edges change
        // Note: Should this ALSO update upstream and downstream ports? If not, why not?
        .onChange(of: graph.selectedEdges) {
            switch coordinate {
            case .output:
                updateOutputColor(output: self.rowObserver, graphState: graph)
            case .input:
                updateInputColor(input: self.rowObserver, graphState: graph)
            }
        }
    }

    @MainActor
    func updatePortViewData(newOrigin: CGPoint) {
        // log("PortEntryView: updatePortViewData for port \(self.coordinate)")
        let adjustedOriginPoint = self.createPreferencePoint(from: newOrigin)
        self.rowObserver.anchorPoint = adjustedOriginPoint
    }

    /// Creates the anchor point for preferences data--modifies from some origin point.
    func createPreferencePoint(from origin: CGPoint) -> CGPoint {

        if case .input = self.coordinate {
            let offset = (Self.height + 4) / 2
            // + 4 required to fully cover input's port
            return .init(x: origin.x + offset + 4, // + 6 seems too much
                         y: origin.y + offset)
        } else {
            let offset = (Self.height + 4) / 2
            return .init(x: origin.x + offset,
                         y: origin.y + offset)
        }

        // ORIGINAL
        //        let offset = (Self.height + 4) / 2
        //        return .init(x: origin.x + offset,
        //                     y: origin.y + offset)
    }
}

extension Color {
    static let HITBOX_COLOR = Color.white.opacity(0.001)
}

struct PortEntryExtendedHitBox: View {
    @Bindable var rowObserver: NodeRowObserver
    let coordinate: PortViewType

    // NOTE: We want to place the gesture detectors on the .overlay'd view.
    var body: some View {
        Color.HITBOX_COLOR
            .frame(width: EXTENDED_HITBOX_WIDTH,
                   height: EXTENDED_HITBOX_HEIGHT)
            /*
             Used for obtaining the starting diff adjustment for a port drag;
             PortGestureRecognizerView handles the heavy lifting,
             but UIKit pan gesture's location is inaccurate with high velocities,
             creating a noticeable gap between cursor and dragged out
             */
            //            .gesture(DragGesture(minimumDistance: 0,
            // if minDistance = 0, then taps cause immediate appearance of an edge
            .gesture(DragGesture(minimumDistance: 0.05,
                                 // .local = relative to this view
                                 coordinateSpace: .named(NodesView.coordinateNameSpace))
                        .onChanged { gesture in
                            switch coordinate {
                            case .output:                                
                                dispatch(OutputDragged(
                                    outputRowObserver: rowObserver,
                                    gesture: gesture))
                            case .input:
                                // TODO: implement drag start logic for Input as well
                                dispatch(InputDragged(inputObserver: rowObserver,
                                                      dragLocation: gesture.location))
                            }
                        } // .onChanged
                        .onEnded { _ in
                            //                    log("PortEntry: onEnded")
                            onPortDragEnded(coordinate)
                        }
            )
    }
}

// struct PortEntryREPL: View {
//    var body: some View {
//        ZStack {
//            PortEntry(
//                coordinate: .fakeInputCoordinate,
//                color: .loopEdge)
//                .frame(width: 50, height: 50)
//        }.scaleEffect(4)
//
//    }
// }
//
// struct PortEntry_Previews: PreviewProvider {
//    static var previews: some View {
//        PortEntryREPL()
//    }
// }

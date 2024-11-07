//
//  PortView.swift
//  Stitch
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

struct PortEntryView<NodeRowViewModelType: NodeRowViewModel>: View {
    @Environment(\.appTheme) var theme

    let height: CGFloat = 8
    
    @Bindable var rowViewModel: NodeRowViewModelType
    @Bindable var graph: GraphState
    let coordinate: NodeIOPortType

    @MainActor
    var portColor: Color {
        rowViewModel.portColor.color(theme)
    }
    
    var body: some View {
        
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
                    .frame(width: self.height)
                    .offset(x: NodeRowViewModelType.nodeIO == .input ? -4 : 4)
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
        .overlay(PortEntryExtendedHitBox(rowViewModel: rowViewModel,
                                         graphState: graph))
        .animation(.linear(duration: self.animationTime),
                   value: portColor)
        // Update port color on selected edges change
        // Note: Should this ALSO update upstream and downstream ports? If not, why not?
        .onChange(of: graph.selectedEdges) {
            self.rowViewModel.updatePortColor()
        }
    }

    @MainActor
    func updatePortViewData(newOrigin: CGPoint) {
        // log("PortEntryView: updatePortViewData for port \(self.coordinate)")
        let adjustedOriginPoint = self.createPreferencePoint(from: newOrigin)
        self.rowViewModel.anchorPoint = adjustedOriginPoint
    }

    /// Creates the anchor point for preferences data--modifies from some origin point.
    func createPreferencePoint(from origin: CGPoint) -> CGPoint {

        if NodeRowViewModelType.nodeIO == .input {
            let offset = (self.height + 4) / 2
            // + 4 required to fully cover input's port
            return .init(x: origin.x + offset + 4, // + 6 seems too much
                         y: origin.y + offset)
        } else {
            let offset = (self.height + 4) / 2
            return .init(x: origin.x + offset,
                         y: origin.y + offset)
        }

        // ORIGINAL
        //        let offset = (Self.height + 4) / 2
        //        return .init(x: origin.x + offset,
        //                     y: origin.y + offset)
    }
    
    @MainActor
    var isDraggingFromThisOutput: Bool {
        // Only applies if output drag exists and on this port
        guard let outputOnDrag = graph.edgeDrawingObserver.drawingGesture?.output,
              NodeRowViewModelType.nodeIO == .output else {
            return false
        }
        
        return outputOnDrag.id == self.rowViewModel.id
    }
    
    // Only animate port colors if we're dragging from this output
    @MainActor
    var animationTime: Double {
        isDraggingFromThisOutput ? DrawnEdge.animationDuration : .zero
    }
}

extension Color {
    static let HITBOX_COLOR = Color.white.opacity(0.001)
}

struct PortEntryExtendedHitBox<RowViewModel: NodeRowViewModel>: View {
    @Bindable var rowViewModel: RowViewModel
    @Bindable var graphState: GraphState

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
                            rowViewModel.portDragged(gesture: gesture,
                                                     graphState: graphState)
                        } // .onChanged
                        .onEnded { _ in
                            //                    log("PortEntry: onEnded")
                            rowViewModel.portDragEnded(graphState: graphState)
                        }
            )
    }
}

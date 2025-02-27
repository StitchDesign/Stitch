//
//  PortView.swift
//  Stitch
//
//  Created by cjc on 1/21/21.
//

import SwiftUI
import StitchSchemaKit

typealias GraphZoom = CGFloat

let EXTENDED_HITBOX_WIDTH: CGFloat = 32 // 68 // 48 // 40 // 32
let EXTENDED_HITBOX_HEIGHT: CGFloat = 24

let PORT_ENTRY_NON_EXTENDED_HITBOX_SIZE = CGSize(
    width: PORT_VISIBLE_LENGTH,
    height: NODE_ROW_HEIGHT)

let NODE_PORT_HEIGHT: CGFloat = 8

struct PortEntryView<NodeRowViewModelType: NodeRowViewModel>: View {
    @Environment(\.appTheme) private var theme
    
    @Bindable var rowViewModel: NodeRowViewModelType
    @Bindable var graph: GraphState
    @Bindable var graphMultigesture: GraphMultigesture
    var zoomData: CGFloat
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
                    .frame(width: 8)
                    .offset(x: NodeRowViewModelType.nodeIO == .input ? -4 : 4)
            }
            .overlay(PortEntryExtendedHitBox(rowViewModel: rowViewModel,
                                             graphState: graph))
            .animation(.linear(duration: self.animationTime),
                       value: portColor)
        
        // TODO: perf implications updating every port's color when selectedEdges or edgeDrawingObserver changes?
        
        // Update port color on selected edges change
        // Note: Should this ALSO update upstream and downstream ports? If not, why not?
            .onChange(of: graph.selectedEdges) {
                self.rowViewModel.updatePortColor()
            }
            .onChange(of: self.graph.edgeDrawingObserver.drawingGesture.isDefined) { oldValue, newValue in
                self.rowViewModel.updatePortColor()
            }
            .onChange(of: self.graph.edgeDrawingObserver.nearestEligibleInput.isDefined) { oldValue, newValue in
                self.rowViewModel.updatePortColor()
            }
        // ^^ should also update port color eligible
    }
    
    @MainActor
    var isDraggingFromThisOutput: Bool {
        NodeRowViewModelType.nodeIO == .output &&
        self.rowViewModel.isDragging
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
                            rowViewModel.isDragging = true
                            rowViewModel.portDragged(gesture: gesture,
                                                     graphState: graphState)
                        } // .onChanged
                        .onEnded { _ in
                            //                    log("PortEntry: onEnded")
                            rowViewModel.isDragging = false
                            rowViewModel.portDragEnded(graphState: graphState)
                        }
            )
    }
}

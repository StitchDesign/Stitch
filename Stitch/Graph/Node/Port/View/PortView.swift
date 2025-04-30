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

struct PortEntryView<PortUIViewModelType: PortUIViewModel>: View {
    @Environment(\.appTheme) private var theme
    
    @Bindable var portUIViewModel: PortUIViewModelType
    @Bindable var graph: GraphState
    
    let rowId: NodeRowViewModelId
    let nodeIO: NodeIO

    @MainActor
    var portColor: Color {
        portUIViewModel.portColor.color(theme)
    }
        
    var body: some View {
        Rectangle().fill(self.portColor)
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
                    .fill(self.portColor)
                    .frame(width: 8)
                    .offset(x: nodeIO == .input ? -4 : 4)
            }
            .overlay(PortEntryExtendedHitBox(graph: self.graph,
                                             nodeIO: nodeIO,
                                             rowId: rowId))
        // Just for when user has tapped an edge?
            .onChange(of: graph.selectedEdges) {
                self.graph.maybeUpdatePortColor(rowId: rowId, nodeIO: nodeIO)
            }
        
        // TODO: better?: update the portColor of the specific port for the output drag, when/where we actually modify `drawingGesture`
            .onChange(of: self.graph.edgeDrawingObserver.drawingGesture.isDefined) { _, _ in
                self.graph.maybeUpdatePortColor(rowId: rowId, nodeIO: nodeIO)
            }
        
        // Now handled in `findEligibleInput` instead
        //            .onChange(of: self.graph.edgeDrawingObserver.nearestEligibleInput.isDefined) { _, _ in
        //                dispatch(MaybeUpdatePortColor(rowId: rowId, nodeIO: nodeIO))
        //            }
    }
}

/*
 Whenever graph's selectedEdges or drawing gesture (or drawing gesture's nearest eligible input) changes,
 we may need to update the port color on the row view model for this port-entry view.

 When updating that color, we will still need to know whether we have an edge and/or a loop, facts which are provided by the row observer.
 Previously we were accessing this via row view model's row observer delegate, which in any case caused an additional render cycle.
 */
extension GraphState {
    @MainActor
    func maybeUpdatePortColor(rowId: NodeRowViewModelId, nodeIO: NodeIO) {
        switch nodeIO {
            
        case .input:
            self.getInputRowObserver(rowId.asNodeIOCoordinate)?
                .updatePortColorAndUpstreamOutputPortColor(
                    selectedEdges: self.selectedEdges,
                    selectedCanvasItems: self.selectedCanvasItems,
                    drawingObserver: self.edgeDrawingObserver)
        
        case .output:
            self.getOutputRowObserver(rowId.asNodeIOCoordinate)?
                .updatePortColorAndDownstreamInputsPortColors(
                    selectedEdges: self.selectedEdges,
                    selectedCanvasItems: self.selectedCanvasItems,
                    drawingObserver: self.edgeDrawingObserver)
        }
    }
}


extension Color {
    static let HITBOX_COLOR = Color.white.opacity(0.001)
}

struct PortEntryExtendedHitBox: View {
    @Bindable var graph: GraphState
        
    let nodeIO: NodeIO // input vs output
    let rowId: NodeRowViewModelId // how to retrieve the
    
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
                            
                            switch nodeIO {
                            case .input:
                                graph.inputDragged(gesture: gesture, rowId: rowId)
                            case .output:
                                graph.outputDragged(gesture: gesture, rowId: rowId)
                            }
                        } // .onChanged
                        .onEnded { _ in
                            //                    log("PortEntry: onEnded")
                            switch nodeIO {
                            case .input:
                                graph.inputDragEnded()
                            case .output:
                                graph.outputDragEnded()
                            }
                        }
            )
    }
}

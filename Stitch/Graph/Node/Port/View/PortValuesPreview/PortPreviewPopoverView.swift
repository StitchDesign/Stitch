//
//  PortPreviewPopoverView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/3/25.
//

import SwiftUI

let PORT_PREVIEW_POPOVER_MAX_HEIGHT: CGFloat = 420

struct OpenedPortPreview: Equatable, Hashable {
    let port: NodeIOCoordinate
    let nodeIO: NodeIO
    let canvasItemId: CanvasItemId
}

struct PortPreviewOpened: StitchDocumentEvent {
    let port: NodeIOCoordinate
    let nodeIO: NodeIO
    let canvasItemId: CanvasItemId
    
    func handle(state: StitchDocumentViewModel) {
        // Access via document to avoid weak reference
        state.graphUI.openPortPreview = .init(port: port, nodeIO: nodeIO, canvasItemId: canvasItemId)
    }
}

struct PortPreviewPopoverWrapperView: View {
    let openPortPreview: OpenedPortPreview
    @Bindable var canvas: CanvasItemViewModel
    
    var body: some View {
        
        // Find the input or output that has the matching canvas-item-id and row-observer-id
        switch openPortPreview.nodeIO {
        
        case .input:
            if let rowViewModel = canvas.inputViewModels.first(where: {
                $0.rowDelegate?.id == openPortPreview.port
            }),
               let inputObserver = rowViewModel.rowDelegate,
               let anchor = rowViewModel.anchorPoint {
                
                PortPreviewPopoverView(
                    rowObserver: inputObserver,
                    rowViewModel: rowViewModel,
                    anchor: anchor)
            }

        case .output:
            if let rowViewModel = canvas.outputViewModels.first(where: {
                $0.rowDelegate?.id == openPortPreview.port
            }),
               let outputObserver = rowViewModel.rowDelegate,
               let anchor = rowViewModel.anchorPoint {
                
                PortPreviewPopoverView(
                    rowObserver: outputObserver,
                    rowViewModel: rowViewModel,
                    anchor: anchor)
            }
        }
    }
    
}

struct PortPreviewPopoverView<NodeRowObserverType: NodeRowObserver>: View {

    let rowObserver: NodeRowObserverType
    let rowViewModel: NodeRowObserverType.RowViewModelType
    let anchor: CGPoint
    
    @State private var width: CGFloat = .zero
    
    var nodeIO: NodeIO {
        NodeRowObserverType.nodeIOType
    }
    
    func stablePopoverArrow(anchor: CGPoint,
                            positionAdjustment: CGFloat) -> some View {
        
        let arrowOffsetAdjustment: CGFloat = nodeIO == .input ? (self.width/2 - 36) : (-self.width/2 + 36)
        
        return Rectangle().fill(.clear)
            .frame(width: 30, height: 30)
            .background(.ultraThickMaterial)
            .rotationEffect(.degrees(45))
            .position(x: anchor.x + positionAdjustment,
                      y: anchor.y)
            .offset(x: arrowOffsetAdjustment)
    }
    
    var body: some View {
        
        let positionAdjustment: CGFloat = nodeIO == .input ? -self.width/2 : self.width/2
        let popoverOffsetAdjustment: CGFloat = nodeIO == .input ? -32 : 32
        
        ZStack {
            stablePopoverArrow(anchor: anchor,
                               positionAdjustment: positionAdjustment)
            
            PortValuesPreviewView(
                rowObserver: rowObserver,
                rowViewModel: rowViewModel,
                nodeIO: nodeIO)
            
            .background {
                GeometryReader { proxy in
                    Color.clear
                    // IMPORTANT: use .local frame, since .global is affected by zooming and creates infinite loop
                        .onChange(of: proxy.frame(in: .local), initial: true) { _, newFrameData in
                            self.width = newFrameData.size.width
                        }
                }
            }
            .frame(maxHeight: PORT_PREVIEW_POPOVER_MAX_HEIGHT)
            .fixedSize(horizontal: false, vertical: true)
            .position(x: anchor.x + positionAdjustment,
                      y: anchor.y)
            .offset(x: popoverOffsetAdjustment)
            
        } // ZStack
            
    }
}

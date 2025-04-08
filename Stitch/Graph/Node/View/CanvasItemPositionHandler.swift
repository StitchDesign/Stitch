//
//  NodePositionHandler.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/15/22.
//

import SwiftUI
import StitchSchemaKit

struct CanvasItemPositionHandler: ViewModifier {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: CanvasItemViewModel
    
    let zIndex: ZIndex
    
    func body(content: Content) -> some View {
        content
            .zIndex(zIndex)
            .canvasPosition(id: node.id,
                            position: node.position)
            .gesture(CanvasItemDragHandler(document: document,
                                           graph: graph,
                                           canvasItemId: node.id))
    }
}

extension View {
    /// Handles node position, drag gestures, and option+select for duplicating node.
    func canvasItemPositionHandler(document: StitchDocumentViewModel,
                                   graph: GraphState,
                                   node: CanvasItemViewModel,
                                   zIndex: ZIndex) -> some View {
        self.modifier(CanvasItemPositionHandler(document: document,
                                                graph: graph,
                                                node: node,
                                                zIndex: zIndex))
    }
}

/*
 Our key-press listening logic sometimes does not detect when the Option key is let up.
 
 Until we perfect our key-press listening logic, it is safer and more consistent to rely on UIKit for key-listeing on a gesture.
 (Similar to what we do in sidebar click + shift.)
 */
struct CanvasItemDragHandler: UIGestureRecognizerRepresentable {
    let document: StitchDocumentViewModel
    let graph: GraphState
    let canvasItemId: CanvasItemId
    
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        // log("CanvasItemDragHandler: makeUIGestureRecognizer")
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer,
                                         context: Context) {
        let translation = recognizer.translation(in: recognizer.view).toCGSize

        // log("CanvasItemDragHandler: handleUIGestureRecognizerAction")
        switch recognizer.state {
        case .began:
            // If we don't have an active first gesture,
            // and graph isn't already dragging,
            // then set node-drag as active first gesture
            if graph.graphMovement.firstActive == .none {
                if !graph.graphMovement.graphIsDragged {
                    // log("canvasItemMoved: will set .node as active first gesture")
                    graph.graphMovement.firstActive = .node
                }
            }
            
            // Handles option + drag scenario
            if self.optionHeld,
               let nodeId = canvasItemId.nodeCase {
                graph.nodeDuplicateDragged(id: nodeId,
                                           document: document)
            }
            
            // Default dragging scenario
            else {
                guard let canvasItem = graph.getCanvasItem(canvasItemId) else {
                    log("CanvasItemMoved: could not find canas item")
                    return
                }
                
                graph.graphMovement.draggedCanvasItem = canvasItemId
                
                // Dragging an unselected node selects that node
                // and de-selects all other nodes.
                let alreadySelected = graph.isCanvasItemSelected(canvasItem.id)
                if !alreadySelected {
                    // update node's position
                    graph.updateCanvasItemOnDragged(canvasItem, translation: translation)
                    
                    // select the canvas item and de-select all the others
                    graph.selectSingleCanvasItem(canvasItem.id)
                    
                    // add node's edges to highlighted edges; wipe old highlighted edges
                    graph.selectedEdges = .init()
                }
            }
            
            graph.canvasItemMoved(translation: translation,
                                  wasDrag: true,
                                  document: document)
        case .changed:
            graph.canvasItemMoved(translation: translation,
                                  wasDrag: true,
                                  document: document)
            
        case .ended, .cancelled, .failed:
            // log("CanvasItemDragHandler: handleUIGestureRecognizerAction: ended, cancelled or failed")
            dispatch(NodeMoveEndedAction(id: canvasItemId))
            
        default:
            break
            // log("CanvasItemDragHandler: handleUIGestureRecognizerAction: unhandled case")
        }
    }
    
    // Note: Coordinater required to use custom UIGestureRecognizerDelegate methods
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(converter: converter) { optionHeld in
            self.optionHeld = optionHeld
        }
    }
    
    @State var optionHeld: Bool = false
    
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let converter: CoordinateSpaceConverter
        let onOptionHeld: (Bool) -> Void
        
        init(converter: CoordinateSpaceConverter,
             onOptionHeld: @escaping (Bool) -> Void) {
            self.converter = converter
            self.onOptionHeld = onOptionHeld
        }
        
        // Called at start of gesture
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldReceive event: UIEvent) -> Bool {
            if event.modifierFlags.contains(.alternate) {
                log("CanvasItemDragHandler: OPTION DOWN")
                self.onOptionHeld(true)
            } else {
                log("CanvasItemDragHandler: OPTION NOT DOWN")
                self.onOptionHeld(false)
            }
            
            return true
        }
    }
}

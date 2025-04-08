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
        
    @Bindable var node: CanvasItemViewModel
    
    let zIndex: ZIndex
    
    func body(content: Content) -> some View {
        content
            .zIndex(zIndex)
            .canvasPosition(id: node.id,
                            position: node.position)
            .gesture(CanvasItemDragHandler(canvasItemId: node.id))
    }
}

extension View {
    /// Handles node position, drag gestures, and option+select for duplicating node.
    func canvasItemPositionHandler(document: StitchDocumentViewModel,
                                   node: CanvasItemViewModel,
                                   zIndex: ZIndex) -> some View {
        self.modifier(CanvasItemPositionHandler(document: document,
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
    let canvasItemId: CanvasItemId
    
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        // log("CanvasItemDragHandler: makeUIGestureRecognizer")
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer,
                                         context: Context) {
        // log("CanvasItemDragHandler: handleUIGestureRecognizerAction")
        switch recognizer.state {
            
        case .changed:
            let translation = recognizer.translation(in: recognizer.view).toCGSize
            
            // log("CanvasItemDragHandler: handleUIGestureRecognizerAction: changed")
            if self.optionHeld,
               let nodeId = canvasItemId.nodeCase {
                dispatch(NodeDuplicateDraggedAction(
                    id: nodeId,
                    translation: translation))
            } else {
                dispatch(CanvasItemMoved(canvasItemId: canvasItemId,
                                         translation: translation,
                                         wasDrag: true))
            }
            
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

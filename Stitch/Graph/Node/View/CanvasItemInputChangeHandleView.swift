//
//  CanvasItemInputChangeHandleView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/23/25.
//

import SwiftUI

// TODO: if we are at the minimum number of inputs, reset something so that we don't have an awkward gap between the bottom-bar/handle and how much farther we moved our cursor up; alternatively, may want to use absolute position
struct CanvasItemInputChangeHandleViewModier: ViewModifier {
    
    @State private var previousTranslationY: CGFloat? = nil
    
    let scale: CGFloat
    let nodeId: NodeId
    let canAddInput: Bool
    @Binding var nodeBodyHovered: Bool
    
    var showHandle: Bool {
        withAnimation {
#if targetEnvironment(macCatalyst)
            return canAddInput && self.nodeBodyHovered
#else
            return canAddInput // hover on iPad requires trackpad
#endif
        }
        
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                
                if showHandle {
                    
                    handleBox
                        .onHover(perform: { isHovering in
                            self.nodeBodyHovered = isHovering
                        })
                    // Very important to use .global coordinate space
                        .gesture(DragGesture(coordinateSpace: .global)
                            .onChanged({ amount in
                                self.onDrag(amount.translation.height)
                            }).onEnded({ _ in
                                self.previousTranslationY = nil
                            }))
                }
            }
    }
    
    var handleBox: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.gray)
            .frame(width: 80, height: 8)
            .offset(y: -3)
            // larger hit area, especially for when zoomed out
            .overlay {
                Rectangle().fill(.white.opacity(0.001))
                    .frame(width: 120, height: 30)
            }
    }
    
    func onDrag(_ currentTranslationY: CGFloat) {
        guard let previousTranslationY = self.previousTranslationY else {
            self.previousTranslationY = currentTranslationY
            return
        }
        
        let isDraggingUp = currentTranslationY < previousTranslationY
        let isDraggingDown = currentTranslationY > previousTranslationY
        
        let translationDiff = previousTranslationY.magnitude - currentTranslationY.magnitude
        
        // Feels best?
//        let changeInputCount = translationDiff.magnitude > (NODE_ROW_HEIGHT + 12)
        let changeInputCount = translationDiff.magnitude > ((NODE_ROW_HEIGHT + 12) * scale)
        
        // log("dragged: currentTranslationY: \(currentTranslationY)")
        // log("dragged: previousTranslationY: \(previousTranslationY)")
        // log("dragged: change: translationDiff \(translationDiff)")
        
        if changeInputCount {
            
            self.previousTranslationY = currentTranslationY
            
            if isDraggingUp {
                // If we stop being able to remove inputs, then reset translation?
                dispatch(InputRemovedAction(nodeId: nodeId))
            } else if isDraggingDown {
                dispatch(InputAddedAction(nodeId: nodeId))
            }
        }
    }
}

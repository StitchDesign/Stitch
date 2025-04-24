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
    
    let nodeId: NodeId
    let canAddInput: Bool
    @Binding var nodeBodyHovered: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                
                if canAddInput, self.nodeBodyHovered {
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray)
                        .frame(width: 80, height: 8)
                        .offset(y: -3)
                        .onHover(perform: { isHovering in
                            self.nodeBodyHovered = isHovering
                        })
                    
                        // Very important to use .global coordinate space
                        .gesture(DragGesture(coordinateSpace: .global).onChanged({ amount in
                            let currentTranslationY = amount.translation.height
                            
                            guard let previousTranslationY = self.previousTranslationY else {
                                self.previousTranslationY = currentTranslationY
                                return
                            }
                            
                            let isDraggingUp = currentTranslationY < previousTranslationY
                            let isDraggingDown = currentTranslationY > previousTranslationY
                            
                            let translationDiff = previousTranslationY.magnitude - currentTranslationY.magnitude

                            // Feels best?
                            let changeInputCount = translationDiff.magnitude > (NODE_ROW_HEIGHT + 12)
                            
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
                        }).onEnded({ _ in
                            self.previousTranslationY = nil
                        }))
                }
            }
    }
}

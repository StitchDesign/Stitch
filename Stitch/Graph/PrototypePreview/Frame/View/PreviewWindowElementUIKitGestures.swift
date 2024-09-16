//
//  PreviewWindowElementGestures.swift
//  prototype
//
//  Created by Elliot Boschwitz on 12/1/21.
//

import SwiftUI
import StitchSchemaKit

// TODO: we likely need to inject the SwiftUI view into the UIKit gesture handler
// tricky?: handling when layers resize?

//// A view modifier attached to a given preview window element
//struct PreviewWindowElementUIKitGestures: ViewModifier {
//    @Bindable var graph: GraphState
//    let interactiveLayer: InteractiveLayer
//    let position: CGPoint
//    let size: CGSize
//    let parentSize: CGSize
//
//    func body(content: Content) -> some View {
//
//        return content
//            // .overlay(UIKitGestureRecognizer) needs to come BEFORE SwiftUI gesture handlers
//            .overlay {
//                PreviewElementTrackpadPanView(
//                    interactiveLayer: interactiveLayer,
//                    position: position,
//                    size: size,
//                    parentSize: parentSize,
//                    graph: graph)
//            }
//    } // body
//}


struct PreviewWindowElementSwiftUIGestures: ViewModifier {
    @Bindable var document: StitchDocumentViewModel
    let interactiveLayer: InteractiveLayer
    let position: CGPoint
    let pos: StitchPosition // for factoring out .anchoring for press node
    let size: CGSize
    let parentSize: CGSize
        
    // e.g. ~5 for Switch; 0 for all other layers
    let minimumDragDistance: Double
        
    @MainActor
    func getPressInteractionIds() -> NodeIdSet? {
        document.getPressInteractionIds(for: interactiveLayer.id.layerNodeId)
    }
    
    @MainActor
    var tapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                if let pressIds = self.getPressInteractionIds() {
                    self.interactiveLayer.secondPressEnded = document.graphStepState.graphTime
                    document.calculate(pressIds)
                }
            }
            .exclusively(before:
                            TapGesture()
                .onEnded {
                    if let pressIds = self.getPressInteractionIds() {
                        self.interactiveLayer.firstPressEnded = document.graphStepState.graphTime
                        document.calculate(pressIds)
                    }
                }
            )
    }
    
    @MainActor
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: minimumDragDistance)
            .onChanged {
                // log("PreviewWindowElementGestures: DragGesture: id: \(interactiveLayer.id) onChanged: \($0)")
                
                // TODO: come up with a better, more accurate velocity calculation
                // (average vs momentaneous velocity?)
                let velocity = CGSize(
                    width: $0.predictedEndLocation.x - $0.location.x,
                    height: $0.predictedEndLocation.y - $0.location.y)
                
                // Factor out anchoring (i.e. position + size/2 + anchoring)
                let location = CGPoint(x: $0.location.x - pos.x,
                                       y: $0.location.y - pos.y)
                                
                document.layerDragged(interactiveLayer: interactiveLayer,
                                      location: location, // // PRESS NODE ONLY
                                      translation: $0.translation,
                                      velocity: velocity,
                                      parentSize: parentSize,
                                      childSize: size,
                                      childPosition: position)
            }
            .onEnded {  _ in
                // log("PreviewWindowElementGestures: DragGesture: id: \(interactiveLayer.id) onEnded")
                document.layerDragEnded(interactiveLayer: interactiveLayer,
                                     parentSize: parentSize,
                                     childSize: size)
            }
    }
    
    func body(content: Content) -> some View {
        return content
        // SwiftUI gestures need to come AFTER UIKit gestures
            .simultaneousGesture(self.dragGesture)
        
        // `TapGesture`s need to come AFTER `DragGesture`
            .simultaneousGesture(self.tapGesture)
    } 
}

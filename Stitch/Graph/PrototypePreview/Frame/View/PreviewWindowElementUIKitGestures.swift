//
//  PreviewWindowElementGestures.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/1/21.
//

import SwiftUI
import StitchSchemaKit

struct PreviewWindowElementSwiftUIGestures: ViewModifier {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let interactiveLayer: InteractiveLayer
    let position: CGPoint
    let size: LayerSize
    let readSize: CGSize
    let anchoring: Anchoring
    let parentSize: CGSize
        
    // e.g. ~5 for Switch; 0 for all other layers
    let minimumDragDistance: Double
       
    // TODO: can you just use the layerViewModel.readSize ?
    var sizeForAnchoringAndGestures: CGSize {
        size.asCGSize(parentSize)
    }
    
    // Note: `position` for gesture needs to ignore the .offset transformation,
    // i.e. do NOT subtract parentSize/2 from the position
    var posForGesture: StitchPosition {
        adjustPosition(
            // SEE NOTE IN `asCGSizeForLayer`
            size: size.asCGSizeForLayer(parentSize: parentSize,
                                        readSize: readSize),
            position: position,
            anchor: anchoring,
            parentSize: parentSize,
            isPinnedRendering: true)
    }
    
    @MainActor
    func getPressInteractionIds() -> NodeIdSet? {
        graph.getPressInteractionIds(for: interactiveLayer.id.layerNodeId)
    }
  
    @MainActor
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: minimumDragDistance) // implicitly: .local
            .onChanged {
                // TODO: come up with a better, more accurate velocity calculation
                // (average vs momentaneous velocity?)
                let velocity = CGSize(
                    width: $0.predictedEndLocation.x - $0.location.x,
                    height: $0.predictedEndLocation.y - $0.location.y)
                
                // Factor out anchoring (i.e. position + size/2 + anchoring)
                let location = CGPoint(x: $0.location.x - posForGesture.x,
                                       y: $0.location.y - posForGesture.y)
                
//                log("PreviewWindowElementGestures: DragGesture: onChanged: id: \(interactiveLayer.id)")
//                log("PreviewWindowElementGestures: DragGesture: onChanged: $0.location: \($0.location)")
//                log("PreviewWindowElementGestures: DragGesture: onChanged: pos: \(pos)")
//                log("PreviewWindowElementGestures: DragGesture: onChanged: location: \(location)")
            
                graph.layerDragged(interactiveLayer: interactiveLayer,
                                   location: location, // // PRESS NODE ONLY
                                   translation: $0.translation,
                                   velocity: velocity,
                                   parentSize: parentSize,
                                   childSize: sizeForAnchoringAndGestures,
                                   childPosition: position)
            }
            .onEnded {  _ in
                // log("PreviewWindowElementGestures: DragGesture: id: \(interactiveLayer.id) onEnded")
                graph.layerDragEnded(interactiveLayer: interactiveLayer,
                                     parentSize: parentSize,
                                     childSize: sizeForAnchoringAndGestures)
            }
    }
    
    func body(content: Content) -> some View {
        return content
        // SwiftUI gestures need to come AFTER UIKit gestures
            .simultaneousGesture(self.dragGesture)
        
        // `TapGesture`s need to come AFTER `DragGesture`
            .simultaneousGesture(TapGesture(count: 2).onEnded({
                if let pressIds = self.getPressInteractionIds() {
                    // Set true here, then set false in press node eval
                    self.interactiveLayer.doubleTapped = true
                    graph.scheduleForNextGraphStep(pressIds)
                }
            }))
            .simultaneousGesture(TapGesture(count: 1).onEnded {
                if let pressIds = self.getPressInteractionIds() {
                    // Set true here, then set false in press node eval
                    self.interactiveLayer.singleTapped = true
                    graph.scheduleForNextGraphStep(pressIds)
                }
            })
    }
}

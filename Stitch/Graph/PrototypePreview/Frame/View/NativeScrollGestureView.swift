//
//  NativeScrollGestureView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/3/24.
//

import SwiftUI

struct NativeScrollGestureView: ViewModifier {
    
    let layerViewModel: LayerViewModel
                    
    @State var scrollPosition: ScrollPosition = .init(edge: .top)
    
    // Raw, unchanged offset reported by the ScrollView; used to:
    // (1) offset the ScrollView's displacement of the layer and
    // (2) update the scroll interaction node's output
    @State var scrollOffset: CGPoint = .zero
    
    @Bindable var graph: GraphState
    
    
    @MainActor
    func getScrollInteractionIds() -> NodeIdSet? {
        graph.getScrollInteractionIds(for: layerViewModel.id.layerNodeId)
    }
    
    var hasScrollInteraction: Bool {
        self.getScrollInteractionIds()?.contains(layerViewModel.id.layerNodeId.asNodeId) ?? false
    }
    
    var scrollAxes: Axis.Set {
//        [.horizontal, .vertical]
        [.vertical]
    }
    
    func body(content: Content) -> some View {
//        if !hasScrollInteraction {
//            content
//        } else {
        if true {
            ScrollView(scrollAxes) {
                content
                    // factor out parent-scroll's offset
                    .offset(x: self.scrollOffset.x,
                            y: self.scrollOffset.y)
            }
            
            .scrollPosition(self.$scrollPosition)
            
            .onScrollGeometryChange(for: CGPoint.self) { geometry in
                // Note: the scroll view's reported value; can be manipulated, but does not affect the scroll view's scrolling, which has already happened
                geometry.contentOffset
            } action: { oldValue, newValue in
                log("onScrollGeometryChange: newValue \(newValue) for layerViewModel.id \(layerViewModel.id)")
                
                // Always update the raw, unmodified scrollOfset, so that child is not automatically moved as parent moves
                self.scrollOffset = newValue
                
                self.layerViewModel
                    .interactiveLayer
                    .nativeScrollState
                    .rawScrollViewOffset = .init(
                        // why do you have to make these negative ? matches Origami but
                        x: (-newValue.x).asPositiveZero,
                        y: (-newValue.y).asPositiveZero
                    )
                
            }
        }
    }
}

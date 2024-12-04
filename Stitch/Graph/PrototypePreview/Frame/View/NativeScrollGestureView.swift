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
//        graph.getScrollInteractionIds(for: layerViewModel.id.layerNodeId)
        graph.getScrollInteractionIds(for: layerViewModel.interactiveLayer.id.layerNodeId)
    }
    
    var hasScrollInteraction: Bool {
//        let k = self.getScrollInteractionIds()?.contains(layerViewModel.id.layerNodeId.asNodeId) ?? false
        
        let scrollPatchesDict: [LayerNodeId: NodeIdSet] = graph.scrollInteractionNodes
        
        log("NativeScrollGestureView: hasScrollInteraction: scrollPatchesDict: \(scrollPatchesDict)")
        
        let assignedScrollPatches: NodeIdSet = scrollPatchesDict.get(layerViewModel.id.layerNodeId) ?? .init()
        
        log("NativeScrollGestureView: hasScrollInteraction: assignedScrollPatches: \(assignedScrollPatches)")
        
        let k = !assignedScrollPatches.isEmpty
        
//        let k = self.getScrollInteractionIds()?.contains(layerViewModel.interactiveLayer.id.layerNodeId.asNodeId) ?? false
        
        log("NativeScrollGestureView: hasScrollInteraction: k: \(k)")
        return k
    }
    
    var nativeScrollState: NativeScrollInteractionLayer {
        layerViewModel.interactiveLayer.nativeScrollState
    }
    
    var scrollAxes: Axis.Set {
//        [.horizontal, .vertical]
//        [.vertical]
        self.nativeScrollState.scrollAxes
    }
        
    // Needed to force a complete re-render when
    // IDEALLY: keep offset
    @State var viewId: UUID = .init()
    
//    @State var initialized: Bool = false
    
    func body(content: Content) -> some View {
        if !hasScrollInteraction {
            content
        } else {
            // Does view properly re-render if this change?
            // Or do we need `.onChange(of: layerViewModel.scrollYEnabled) { self.id = .init() }` ?
            ScrollView(scrollAxes) {
                content
                    .border(.yellow)
                
                // apply additional `.frame` for custom content size; but only if that dimension is > 0
                    .frame(width: nativeScrollState.contentSize.width > 0 ? nativeScrollState.contentSize.width : nil)
                
                    .frame(height: nativeScrollState.contentSize.height > 0 ? nativeScrollState.contentSize.height : nil)
                    .border(.teal)
                
                
                    // factor out parent-scroll's offset
                    .offset(x: self.scrollOffset.x,
                            y: self.scrollOffset.y)
            }
//            .id(self.viewId)
//            .id(self.viewId)
            
            // What happens if this is toggled?
//            .scrollIndicators(layerViewModel.interactiveLayer.nativeScrollState.indicatorsHidden ? .hidden : .automatic)
            
            // TODO: allow user to control? requires forced re-rendering the view
            .scrollIndicators(.hidden)
            
            // TODO: allow user to control?
            .scrollBounceBehavior(.basedOnSize)
            
            .scrollPosition(self.$scrollPosition)
            
            .onScrollGeometryChange(for: CGPoint.self) { geometry in
                // Note: the scroll view's reported value; can be manipulated, but does not affect the scroll view's scrolling, which has already happened
                geometry.contentOffset
            } action: { oldValue, newValue in
                log("NativeScrollGestureView: onScrollGeometryChange: newValue \(newValue) for layerViewModel.id \(layerViewModel.id)")
                
//                guard self.initialized else {
//                    log("NativeScrollGestureView: onScrollGeometryChange: returning early")
//                    return
//                }
                
                // Always update the raw, unmodified scrollOfset, so that child is not automatically moved as parent moves
                self.scrollOffset = newValue
                
                self.layerViewModel
                    .interactiveLayer
                    .nativeScrollState
                    .rawScrollViewOffset = .init(
                        // why do you have to make these negative ? matches Origami
                        x: (-newValue.x).asPositiveZero,
                        y: (-newValue.y).asPositiveZero
                    )
                
            } // .onScrollGeometryChange
            
//            .onAppear(perform: {
//                log("NativeScrollGestureView: onAppear")
//                self.scrollPosition.scrollTo(
//                    x: self.scrollOffset.x,
//                    y: self.scrollOffset.y)
//            })
            
            // TODO: how to tackle some of the awkward scrolling that happens after we toggle x/y scroll enabled ?
//            .onChange(of: self.scrollAxes, { oldValue, newValue in
//                log("NativeScrollGestureView: scrollAxes changed")
//                self.initialized = false
//                self.viewId = .init()
//                log("NativeScrollGestureView: scrollAxes changed: changed viewId")
//                self.scrollPosition.scrollTo(
//                    x: self.scrollOffset.x,
//                    y: self.scrollOffset.y)
//                self.initialized = true
//            })
            
            // Responding to changes to JumpStyle input
            
            .onChange(of: nativeScrollState.jumpToX) { _, newValue in
                
                guard newValue && nativeScrollState.xScrollEnabled else {
                    return
                }
                
                let jump = {
                    self.scrollPosition.scrollTo(x: nativeScrollState.jumpPositionX,
                                                 y: self.scrollOffset.y)
                }
                
                if nativeScrollState.jumpStyleX == .animated {
                    withAnimation {
                        // Must specifiy `y:` as well, so that y is not set to 0
                        jump()
                    }
                } else {
                    jump()
                }
            } // .onChange
            
            .onChange(of: nativeScrollState.jumpToY) { _, newValue in
                
                guard newValue && nativeScrollState.yScrollEnabled else {
                    return
                }
                
                let jump = {
                    self.scrollPosition.scrollTo(x: self.scrollOffset.x,
                                                 y: nativeScrollState.jumpPositionY)
                }
                
                if nativeScrollState.jumpStyleY == .animated {
                    withAnimation {
                        jump()
                    }
                } else {
                    jump()
                }
            } // .onChange

            .onChange(of: graph.graphStepState.graphFrameCount) { _, newValue in
                if newValue == Int(2) {
                    self.scrollPosition.scrollTo(edge: .top)
                }
            } // .onChange
            
        } // if / else
                
    } // var body
}

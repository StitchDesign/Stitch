//
//  NativeScrollGestureView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/3/24.
//

import SwiftUI


struct NativeScrollGestureView<T: View>: View {
    
    let layerViewModel: LayerViewModel
    @Bindable var graph: GraphState
    @ViewBuilder var view: () -> T
        
    var hasScrollInteraction: Bool {
        let scrollPatchesDict: [LayerNodeId: NodeIdSet] = graph.scrollInteractionNodes
        // log("NativeScrollGestureView: hasScrollInteraction: scrollPatchesDict: \(scrollPatchesDict)")
        let assignedScrollPatches: NodeIdSet = scrollPatchesDict.get(layerViewModel.id.layerNodeId) ?? .init()
        // log("NativeScrollGestureView: hasScrollInteraction: assignedScrollPatches: \(assignedScrollPatches)")
        let _hasScrollInteraction = !assignedScrollPatches.isEmpty
        
        log("NativeScrollGestureView: hasScrollInteraction: _hasScrollInteraction: \(_hasScrollInteraction)")
        
        return _hasScrollInteraction
    }
    
    var body: some View {
        // logInView("NativeScrollGestureView: var body")
        if hasScrollInteraction {
            view()
                .modifier(NativeScrollGestureViewInner(
                    layerViewModel: layerViewModel,
                    graph: graph))
        } else {
            view()
        }
    }
}

struct NativeScrollGestureViewInner: ViewModifier {
    
    let layerViewModel: LayerViewModel
    
    @Bindable var graph: GraphState
        
    // Raw, unchanged offset reported by the ScrollView; used to:
    // (1) offset the ScrollView's displacement of the layer and
    // (2) update the scroll interaction node's output
    @State var scrollOffset: CGPoint = .zero
    
    // Programmatic manipulation of the ScrollView's position
    @State var scrollPosition: ScrollPosition = .init(edge: .top) // .top vs .bottom makes no difference?
    
    var nativeScrollState: NativeScrollInteractionLayer {
        layerViewModel.interactiveLayer.nativeScrollState
    }
    
    var scrollAxes: Axis.Set {
        self.nativeScrollState.scrollAxes
    }
    
    @State var viewId: UUID = .init()
    
    func body(content: Content) -> some View {
        // logInView("NativeScrollGestureViewInner: var body")
        
        ScrollView(scrollAxes) {
            
            content
            
//            // apply additional `.frame` for custom content size; but only if that dimension is > 0
                .frame(width: nativeScrollState.contentSize.width > 0 ? nativeScrollState.contentSize.width : nil)
                .frame(height: nativeScrollState.contentSize.height > 0 ? nativeScrollState.contentSize.height : nil)
                
//                .border(.teal, width: 16)
            
            // factor out parent-scroll's offset, so that view does not move unless we explicitly connect scroll interaction node's output to the layer's position input
                .offset(x: self.scrollOffset.x,
                        y: self.scrollOffset.y)
            
//                .border(.green, width: 12)
        }
        
        /*
         Required for forced re-render when e.g. scrollable-axes change
         TODO: do not reset scroll-offset when scroll-axes changed
         Note: order appears to matter? e.g. `.id` here vs after `.scrollPosition`
         */
        .id(self.viewId)
        
        // TODO: allow user to control? requires forced re-rendering the view
        .scrollIndicators(.hidden)
        
        // TODO: allow user to control?
        .scrollBounceBehavior(.basedOnSize)
        
        // For programmatically manipulating the scroll view's position
        .scrollPosition(self.$scrollPosition)
        
        .onScrollGeometryChange(for: CGPoint.self) { geometry in
            // Note: the scroll view's reported value; can be manipulated, but does not affect the scroll view's scrolling, which has already happened
            geometry.contentOffset
        } action: { oldValue, newValue in
            // log("NativeScrollGestureViewInner: onScrollGeometryChange: newValue \(newValue) for layerViewModel.id \(layerViewModel.id)")
            // log("NativeScrollGestureViewInner: onScrollGeometryChange: newValue \(newValue)")
            
            // Always update the raw, unmodified scrollOffset, so that child is not automatically moved as parent moves
            self.scrollOffset = newValue
            
            self.layerViewModel.interactiveLayer.nativeScrollState.rawScrollViewOffset = .init(
                // why do you have to make these negative ? matches Origami
                x: (-newValue.x).asPositiveZero,
                y: (-newValue.y).asPositiveZero
            )
        } // .onScrollGeometryChange
        
        // TODO: how to tackle some of the awkward scrolling that happens after we toggle x/y scroll enabled ?
        .onChange(of: self.scrollAxes, { oldValue, newValue in
            // log("NativeScrollGestureViewInner: scrollAxes changed: \(nativeScrollState.rawScrollViewOffset.x)")
            
            self.viewId = .init()
            // log("NativeScrollGestureViewInner: scrollAxes changed: changed viewId: \(nativeScrollState.rawScrollViewOffset.x)")
            
            // Even when called with the proper values, this gets ignored?
            self.scrollPosition.scrollTo(
                x: self.scrollOffset.x,
                y: self.scrollOffset.y
            )
            // log("NativeScrollGestureViewInner: scrollAxes changed: scrolled: \(nativeScrollState.rawScrollViewOffset.x)")
        })
        
        // TODO: seems to be called *twice* when we do `self.viewId = .init()` ?
        //        .onChange(of: self.viewId, { oldValue, newValue in
        //            log("NativeScrollGestureViewInner: viewId changed: \(nativeScrollState.rawScrollViewOffset.x)")
        //            self.scrollPosition.scrollTo(
        //                x: self.nativeScrollState.rawScrollViewOffset.x,
        //                y: self.scrollOffset.y
        //            )
        //        })
        
        
        // Responding to changes to JumpStyle input
        
        .onChange(of: nativeScrollState.jumpToX) { _, newValue in

            guard newValue && nativeScrollState.xScrollEnabled else {
                return
            }
            
            let jump = {
                self.scrollPosition.scrollTo(x: nativeScrollState.jumpPositionX,
                                             // Must specify `y:` as well, so that y is not set to 0
                                             y: self.scrollOffset.y)
            }
            
            if nativeScrollState.jumpStyleX == .animated {
                withAnimation {
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
        
        
        .onChange(of: nativeScrollState.graphReset) { _, newValue in
            if newValue {
                self.scrollPosition.scrollTo(edge: .top) // top-left corner
            }
        } // .onChange
        
    } // var body
}

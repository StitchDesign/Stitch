//
//  LayerInputOnGraphView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/19/24.
//

import SwiftUI
import StitchSchemaKit

struct LayerNodeInputView: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel // for overall layer node

    @Bindable var rowObserver: InputNodeRowObserver
    @Bindable var rowViewModel: InputNodeRowViewModel
    @Bindable var canvasItem: CanvasItemViewModel
    
    @Bindable var layerNode: LayerNodeViewModel
    
    // TODO: fix when comment boxes added back
    let atleastOneCommentBoxSelected: Bool = false
    
    var body: some View {
        LayerNodeRowView(graph: graph,
                         node: node,
                         layerNode: layerNode,
                         canvasItem: canvasItem,
                         atleastOneCommentBoxSelected: atleastOneCommentBoxSelected) {
            HStack {
                NodeInputView(graph: graph,
                              rowObserver: rowObserver,
                              rowData: rowViewModel,
                              forPropertySidebar: false,
                              propertyIsSelected: false,
                              propertyIsAlreadyOnGraph: true,
                              isCanvasItemSelected: canvasItem.isSelected)
                Spacer()
            }
        }
    }
}

struct LayerNodeOutputView: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel // for overall layer node

    @Bindable var rowObserver: OutputNodeRowObserver
    @Bindable var rowViewModel: OutputNodeRowViewModel
    @Bindable var canvasItem: CanvasItemViewModel
    
    @Bindable var layerNode: LayerNodeViewModel
    
    // TODO: fix when comment boxes added back
    let atleastOneCommentBoxSelected: Bool = false
    
    var body: some View {
        LayerNodeRowView(graph: graph,
                         node: node,
                         layerNode: layerNode,
                         canvasItem: canvasItem,
                         atleastOneCommentBoxSelected: atleastOneCommentBoxSelected) {
            HStack {
                Spacer()
                NodeOutputView(graph: graph,
                              rowObserver: rowObserver,
                              rowData: rowViewModel,
                              forPropertySidebar: false,
                              propertyIsSelected: false,
                              propertyIsAlreadyOnGraph: true,
                              isCanvasItemSelected: canvasItem.isSelected)
            }
        }
    }
}


struct LayerNodeRowView<RowView>: View where RowView: View {
    
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel // for overall layer node
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var canvasItem: CanvasItemViewModel
    
    // TODO: fix when comment boxes added back
    var atleastOneCommentBoxSelected: Bool = false
    
    @ViewBuilder var rowView: () -> RowView
    
    @MainActor
    var isSelected: Bool {
        self.canvasItem.isSelected
    }
    
    var isHiddenLayer: Bool {
        let isVisibleInSidebar = layerNode.hasSidebarVisibility
        return !isVisibleInSidebar
    }
    
    var body: some View {
        // Node title with node tag menu button etc.
        ZStack {
            rowBody
#if targetEnvironment(macCatalyst)
                .contextMenu { tagMenu } // Catalyst right-click to open node tag menu
#endif
                .simultaneousGesture(TapGesture(count: 1).onEnded({
                    log("LayerInputOnGraphView: .simultaneousGesture(TapGesture(count: 1)")
                    canvasItem.isTapped(graph: graph)
                }))
        } // ZStack
        .canvasItemPositionHandler(graph: graph,
                                   node: canvasItem,
                                   position: self.canvasItem.position,
                                   zIndex: self.canvasItem.zIndex,
                                   usePositionHandler: true)
    }
        
    @MainActor
    var rowBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
            CanvasItemBodyDivider()
            rowView()
                .modifier(CanvasItemBodyPadding())
        }
        .fixedSize()
        .modifier(CanvasItemBackground(color: self.node.color.body))
        .overlay(content: {
            if isHiddenLayer {
                /*
                 TODO: how to indicate from the graph view that a given layer node's layers are hidden?
                 - use 30% black overlay in Light mode, 30% white overlay in Dark mode?
                 - use theme color?
                 - use crossed-out eye icon near node title?
                 */
                Color.black.opacity(0.3)
                    .cornerRadius(CANVAS_ITEM_CORNER_RADIUS)
                    .allowsHitTesting(false)
            } else {
                EmptyView()
            }
        })
        
        .modifier(CanvasItemBoundsReader(
            graph: graph,
            canvasItem: canvasItem,
            splitterType: nil, // N/A for LIG
            disabled: false, // N/A for LIG
            // N/A for LIG
            updateMenuActiveSelectionBounds: false))
        .modifier(CanvasItemSelectedViewModifier(isSelected: isSelected))
    }
 
    @MainActor
    var title: some View {
        HStack {
            CanvasItemTitleView(graph: graph,
                                node: node,
                                isNodeSelected: isSelected,
                                canvasId: canvasItem.id)
            .modifier(CanvasItemTitlePadding())
            
            Spacer()
            
            CanvasItemTag(isSelected: isSelected,
                          nodeTagMenu: tagMenu)
            .opacity(isSelected ? 1 : 0)
            
//            Menu {
//                nodeTagMenu
//            } label: {
//                Image(systemName: "ellipsis.rectangle")
//            }
//            .buttonStyle(.plain)
//            .scaleEffect(1.4)
//            .frame(width: 24, height: 12)
//            .foregroundColor(STITCH_TITLE_FONT_COLOR)
//            .padding(.trailing, 8)
        }
        
        
    }
    
    @MainActor
    var tagMenu: NodeTagMenuButtonsView {
        NodeTagMenuButtonsView(graph: graph,
                               node: node,
                               canvasItemId: canvasItem.id,
                               activeGroupId: graph.groupNodeFocused?.asGroupNodeId,
                               nodeTypeChoices: .init(), // N/A layer-inputs-on-graph
                               canAddInput: false, // N/A for layer-inputs-on-graph
                               canRemoveInput: false, // N/A for layer-inputs-on-graph
                               atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                               isHiddenLayer: isHiddenLayer)
    }
}

//#Preview {
//    let canvas = CanvasItemViewModel(
//        id: .layerInput(.init(node: .init(),
//                                     keyPath: .size)),
//        // So that we roughly get in the middle of the device screen;
//        // (since we use
//        position: .init(x: 350, y: 350),
//        zIndex: 0,
//        parentGroupNodeId: nil,
//        nodeDelegate: nil)
//    
//    ZStack {
//        Color.blue
//        Color.black.opacity(0.2)
//        LayerNodeInputView(graph: .fakeEmptyGraphState,
//                           node: .mock,
//                           row: ,
//                           canvasItem: canvas,
//                           layerNode: .mock)
//    }
//}

// want to reuse: title, tag menu, position
//
//struct CanvasItemTitle

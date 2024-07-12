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

    @Bindable var row: InputNodeRowObserver
    @Bindable var canvasItem: CanvasItemViewModel
    
    @Bindable var layerNode: LayerNodeViewModel
    
    // TODO: fix when comment boxes added back
    let atleastOneCommentBoxSelected: Bool = false
    
    var body: some View {
        LayerNodeRowView(graph: graph,
                         node: node,
                         row: row,
                         canvasItem: canvasItem,
                         layerNode: layerNode,
                         atleastOneCommentBoxSelected: atleastOneCommentBoxSelected) {
            HStack {
                NodeInputView(graph: graph,
                              node: node,
                              rowObserver: row,
                              rowData: row.rowViewModel,
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

    @Bindable var row: OutputNodeRowObserver
    @Bindable var canvasItem: CanvasItemViewModel
    
    @Bindable var layerNode: LayerNodeViewModel
    
    // TODO: fix when comment boxes added back
    let atleastOneCommentBoxSelected: Bool = false
    
    var body: some View {
        LayerNodeRowView(graph: graph,
                         node: node,
                         row: row,
                         canvasItem: canvasItem,
                         layerNode: layerNode,
                         atleastOneCommentBoxSelected: atleastOneCommentBoxSelected) {
            HStack {
                Spacer()
                NodeOutputView(graph: graph,
                              node: node,
                              rowObserver: row,
                              rowData: row.rowViewModel,
                              forPropertySidebar: false,
                              propertyIsSelected: false,
                              propertyIsAlreadyOnGraph: true,
                              isCanvasItemSelected: canvasItem.isSelected)
            }
        }
    }
}


struct LayerNodeRowView<RowObserver, RowView>: View where RowObserver: NodeRowObserver,
                                                                       RowView: View {
    
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel // for overall layer node

    @Bindable var row: RowObserver
    @Bindable var canvasItem: CanvasItemViewModel
    
    @Bindable var layerNode: LayerNodeViewModel
    
    // TODO: fix when comment boxes added back
    let atleastOneCommentBoxSelected: Bool = false
    
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
                    graph.canvasItemTapped(canvasItem.id)
                }))
            
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Menu {
                            tagMenu
                        } label: {
                            nodeTagMenuIcon
#if !targetEnvironment(macCatalyst)
                            // .border(.yellow)
                                .padding(16) // increase hit area
                            // .border(.blue)
#endif
                        }
#if targetEnvironment(macCatalyst)
                        .buttonStyle(.plain)
                        .scaleEffect(1.4)
                        .frame(width: 24, height: 12)
                        .padding(16)
                        .foregroundColor(STITCH_TITLE_FONT_COLOR)
                        .offset(x: -4, y: -4)
#else
                        
                        // iPad
                        .menuStyle(.button)
                        .buttonStyle(.borderless)
                        .foregroundColor(STITCH_TITLE_FONT_COLOR)
                        .offset(x: -2, y: -4)
#endif
                        // .border(.red)
                    }
                }
            
        } // ZStack
        .canvasItemPositionHandler(graph: graph,
                                   node: canvasItem,
                                   position: self.canvasItem.position,
                                   zIndex: self.canvasItem.zIndex,
                                   usePositionHandler: true)
    }
    
    var nodeTagMenuIcon: some View {
        Image(systemName: "ellipsis.rectangle")
    }
    
    @MainActor
    var rowBody: some View {
        VStack(spacing: 0) {
            title
                .padding([.leading, .trailing], 62)
                .padding(NODE_BODY_PADDING)
            
            rowView()
                .padding(.top, NODE_BODY_PADDING * 2)
                .padding(.bottom, NODE_BODY_PADDING + 4)
                .overlay(
                    // A hack to get a border on one edge without having it push the boundaries
                    // of the view, which was the problem with Divider.
                    Divider()
                        .height(1)
                        .overlay(STITCH_FONT_WHITE_COLOR),
                    alignment: .top)
        }
        .fixedSize()
        .background {
            ZStack {
                VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                self.node.color.body.opacity(0.1)
                //                nodeUIColor.body.opacity(0.3)
                //                nodeUIColor.body.opacity(0.5)
                //                nodeUIColor.body.opacity(0.7)
            }
            .cornerRadius(CANVAS_ITEM_CORNER_RADIUS)
        }
        
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
        CanvasItemTitleView(graph: graph,
                            node: node,
                            isNodeSelected: isSelected)
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
//        id: .layerInputOnGraph(.init(node: .init(),
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

//
//  LayerInputOnGraphView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/19/24.
//

import SwiftUI
import StitchSchemaKit

struct LayerInputOnGraphView: View {
    
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel // for overall layer node

    @Bindable var input: NodeRowObserver
    @Bindable var canvasItem: CanvasItemViewModel

    // Don't need full LayerNodeViewModel, just that layer
    //    @Bindable var layerNode: LayerNodeViewModel
    let layer: Layer
    
    @MainActor
    var isSelected: Bool {
        self.canvasItem.isSelected
    }
    
    var body: some View {
                    
        // Node title with node tag menu button etc.
        ZStack {
            inputBody
#if targetEnvironment(macCatalyst)
                .contextMenu { tagMenu } // Catalyst right-click to open node tag menu
#endif
                .gesture(TapGesture(count: 1).onEnded({
                    log("LayerInputOnGraphView: .simultaneousGesture(TapGesture(count: 1)")
                    graph.nodeTapped(node)
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
        .nodePositionHandler(graph: graph,
                             node: node,
                             position: self.canvasItem.position,
                             zIndex: self.canvasItem.zIndex,
                             usePositionHandler: true)
    }
    
    var nodeTagMenuIcon: some View {
        Image(systemName: "ellipsis.rectangle")
    }
    
    @MainActor
    var inputBody: some View {
        VStack(spacing: 0) {
            title
                .padding([.leading, .trailing], 62)
                .padding(NODE_BODY_PADDING)
            
            inputView
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
            .cornerRadius(NODE_CORNER_RADIUS)
        }
        
        // TODO: add the `disabled layer node` overaly
        
        .modifier(NodeBoundsReader(graph: graph,
                                   id: self.node.id,
                                   splitterType: nil,
                                   disabled: false,
                                   updateMenuActiveSelectionBounds: false))
        .modifier(NodeSelectedView(isSelected: isSelected))
    }
 
    @MainActor
    var title: some View {
        CanvasItemTitleView(graph: graph,
                      node: node,
                      isNodeSelected: isSelected)
    }
    
    var tagMenu: NodeTagMenuButtonsView {
        NodeTagMenuButtonsView(graph: graph,
                               node: node,
                               activeGroupId: nil,
                               nodeTypeChoices: .init(),
                               canAddInput: false,
                               canRemoveInput: false,
                               atleastOneCommentBoxSelected: false,
                               isHiddenLayer: false)
    }
    
    @ViewBuilder @MainActor
    var inputView: some View {
        HStack {
            // See if layer node uses this input
            if let portViewType = input.portViewType {
                NodeInputOutputView(graph: graph,
                                    node: node,
                                    rowData: input,
                                    coordinateType: portViewType,
                                    //                                nodeKind: .layer(layerNode.layer),
                                    nodeKind: .layer(layer),
                                    isNodeSelected: false,
                                    adjustmentBarSessionId: graph.graphUI.adjustmentBarSessionId)
            } else {
                EmptyView()
            }
            
            Spacer()
        }
    }
}

struct FakeLayerInputOnGraphView: View {
    
    var body: some View {
        let node = Layer.oval.getFakeLayerNode()!
        LayerInputOnGraphView(graph: .fakeEmptyGraphState,
                              node: node,
//                              input: node.inputRowObservers().first!,
                              input: node.inputRowObservers()[1],
                              canvasItem: .fakeCanvasItem,
                              layer: node.layerNode!.layer)
    }
}

#Preview {
    ZStack {
        Color.blue
        Color.black.opacity(0.2)
        FakeLayerInputOnGraphView()
    }
}

// want to reuse: title, tag menu, position
//
//struct CanvasItemTitle

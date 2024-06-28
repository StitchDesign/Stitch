//
//  NodeView.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import UIKit
import StitchSchemaKit

struct NodeView<InputsViews: View, OutputsViews: View>: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let isSelected: Bool
    let atleastOneCommentBoxSelected: Bool
    let activeGroupId: GroupNodeId?
    let canAddInput: Bool
    let canRemoveInput: Bool

    // Only for patch nodes
    var sortedUserTypeChoices: [UserVisibleType] = []

    let boundsReaderDisabled: Bool
    let usePositionHandler: Bool
    let updateMenuActiveSelectionBounds: Bool

    // This node is the "real" node of an active insert-node-animation,
    let isHiddenDuringAnimation: Bool

    @ViewBuilder var inputsViews: () -> InputsViews
    @ViewBuilder var outputsViews: () -> OutputsViews

    var id: NodeId {
        self.node.id
    }

    var zIndex: CGFloat {
        self.node.zIndex
    }

    @MainActor
    var displayTitle: String {
        self.node.displayTitle
    }

    var nodeUIColor: NodeUIColor {
        self.node.color
    }

    var userVisibleType: UserVisibleType? {
        self.node.userVisibleType
    }

    var splitterType: SplitterType? {
        self.node.splitterType
    }

    var isLayerNode: Bool {
        self.node.kind.isLayer
    }

    var position: CGPoint {
        self.node.position
    }

    var nodeTagMenuIcon: some View {
        Image(systemName: "ellipsis.rectangle")
    }

    var body: some View {
        // TODO: remove
//        logInView("NodeView body \(self.node.id)")
//        if self.node.patch == .wirelessReceiver {
//            logInView("NodeView body isWirelessReceiver \(self.node.id)")
//        }
        
        ZStack {
            nodeBody
#if targetEnvironment(macCatalyst)
                .contextMenu { nodeTagMenu } // Catalyst right-click to open node tag menu
#endif
            
            /*
             Note: we must order these gestures as `double tap gesture -> single tap simultaneous gesture`.
             
             If both gestures are simultaneous, then a "double tap" user gesture ends up doing a single tap then a double tap then ANOTHER single tap.
             
             If both gestures non-simultaneous, then there is a delay as SwiftUI waits to see whether we did a single or a double tap.
             */
                .gesture(TapGesture(count: 2).onEnded({
                    if self.node.kind.isGroup {
                        log("NodeView: .gesture(TapGesture(count: 2)")
                        log("NodeView: .gesture(TapGesture(count: 2): will set active group")
                        dispatch(GroupNodeDoubleTapped(id: GroupNodeId(id)))
                    }
                }))
            
            // See GroupNodeView for group node double tap
                .simultaneousGesture(TapGesture(count: 1).onEnded({
                    log("NodeView: .simultaneousGesture(TapGesture(count: 1)")
                    graph.canvasItemTapped(node.canvasItemId)
                }))
            
            // TODO: put into a separate ViewModifier
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Menu {
                            nodeTagMenu
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
                                   node: node.canvasUIData,
                                   position: position,
                                   zIndex: zIndex,
                                   usePositionHandler: usePositionHandler)
        .opacity(isHiddenDuringAnimation ? 0 : 1)
    }

    @MainActor
    var nodeBody: some View {
        VStack(spacing: .zero) {
            nodeTitle
                .padding([.leading, .trailing], 62)
                .padding(NODE_BODY_PADDING)

            nodeBodyKind
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
        //        .background(nodeUIColor.body) // ORIGINAL
        .background {
            ZStack {
                VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                nodeUIColor.body.opacity(0.1)
                //                nodeUIColor.body.opacity(0.3)
                //                nodeUIColor.body.opacity(0.5)
                //                nodeUIColor.body.opacity(0.7)
            }
            .cornerRadius(CANVAS_ITEM_CORNER_RADIUS)
        }
        .modifier(CanvasItemBoundsReader(
            graph: graph,
            canvasItem: node.canvasUIData,
            splitterType: splitterType,
            disabled: boundsReaderDisabled,
            updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds))
        //        .cornerRadius(NODE_CORNER_RADIUS)
        .modifier(CanvasItemSelectedViewModifier(isSelected: isSelected))
    }

    var nodeTitle: some View {
        CanvasItemTitleView(graph: graph,
                            node: node,
                            isNodeSelected: isSelected,
                            canvasId: node.canvasItemId)
    }

    var nodeBodyKind: some View {
        HStack(alignment: .top, spacing: NODE_BODY_SPACING) {
            inputsViews()
            Spacer()
            outputsViews()
        }
    }

    var nodeTagMenu: NodeTagMenuButtonsView {
        NodeTagMenuButtonsView(graph: graph,
                               node: node, 
                               canvasItemId: node.canvasItemId,
                               activeGroupId: activeGroupId,
                               nodeTypeChoices: sortedUserTypeChoices,
                               canAddInput: canAddInput,
                               canRemoveInput: canRemoveInput,
                               atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                               // Always false for PatchNodeView
                               isHiddenLayer: false)
    }
}

struct NodeView_REPL: View {

    let devPosition = StitchPosition(width: 500,
                                     height: 500)

    var body: some View {
        ZStack {
            //            Color.orange.opacity(0.2).zIndex(-2)

            FakeNodeView(
                node: Patch.add.getFakePatchNode(
                    //                    customName: "A very long name, much tested and loved and feared and enjoyed"
                    customName: "A very long name"
                )!
            )

        }
        .scaleEffect(2)
        //        .offset(y: -500)
    }
}

//struct SpecNodeView_Previews: PreviewProvider {
//    static var previews: some View {
//        NodeView_REPL()
//            .environment(GraphState(id: .mockProjectId))
//
//        // .previewInterfaceOrientation(.landscapeLeft)
//    }
//}

struct FakeNodeView: View {

    let node: NodeViewModel

    var body: some View {
        NodeTypeView(graph: .init(id: .init(), store: nil),
                     node: node,
                     atleastOneCommentBoxSelected: false,
                     activeIndex: .init(1),
                     groupNodeFocused: nil,
                     adjustmentBarSessionId: .init(id: .fakeId),
                     boundsReaderDisabled: true,
                     usePositionHandler: false,
                     updateMenuActiveSelectionBounds: false)
    }
}

extension GraphState {
    @MainActor
    static let fakeEmptyGraphState: GraphState = .init(id: .init(), store: nil)
}

@MainActor
func getFakeNode(choice: NodeKind,
                 _ nodePosition: CGSize = .zero,
                 _ zIndex: ZIndex = 1,
                 customName: String? = nil) -> NodeViewModel? {

    let graphState = GraphState(id: .fakeId, store: nil)
    
    if let id = graphState.nodeCreated(choice: choice),
       let node = graphState.getNodeViewModel(id) {
                
        if let customName = customName {
            node.title = customName
        }
        
        return node
    }
    
    return nil
}

extension Patch {
    
    // TODO: this default-eval should probably be in `.defaultNode` ?
    @MainActor
    func getFakePatchNode(_ nodePosition: CGSize = .zero,
                          _ zIndex: ZIndex = 1,
                          customName: String? = nil) -> PatchNode? {
        getFakeNode(choice: .patch(self), 
                    nodePosition,
                    zIndex,
                    customName: customName)
    }
}

extension Layer {
    @MainActor
    func getFakeLayerNode(_ nodePosition: CGSize = .zero,
                          _ zIndex: ZIndex = 1,
                          customName: String? = nil) -> LayerNode? {
        getFakeNode(choice: .layer(self),
                    nodePosition,
                    zIndex,
                    customName: customName)
    }
}

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
    @Bindable var node: CanvasItemViewModel
    @Bindable var stitch: NodeViewModel
    @Bindable var graph: GraphState
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

    var zIndex: CGFloat {
        self.node.zIndex
    }

    @MainActor
    var displayTitle: String {
        self.stitch.displayTitle
    }

    var nodeUIColor: NodeUIColor {
        self.stitch.color
    }

    var userVisibleType: UserVisibleType? {
        self.stitch.userVisibleType
    }

    var splitterType: SplitterType? {
        self.stitch.splitterType
    }

    var isLayerNode: Bool {
        self.stitch.kind.isLayer
    }

    var position: CGPoint {
        self.node.position
    }

    var body: some View {
        
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
                    if self.stitch.kind.isGroup {
                        log("NodeView: .gesture(TapGesture(count: 2)")
                        log("NodeView: .gesture(TapGesture(count: 2): will set active group")
                        dispatch(GroupNodeDoubleTapped(id: GroupNodeId(stitch.id)))
                    }
                }))
            
            // See GroupNodeView for group node double tap
                .simultaneousGesture(TapGesture(count: 1).onEnded({
                    log("NodeView: .simultaneousGesture(TapGesture(count: 1)")
                    node.isTapped(graph: graph)
                }))
            
//                .modifier(CanvasItemTag(isSelected: isSelected,
//                                        nodeTagMenu: nodeTagMenu))
        } // ZStack
        .canvasItemPositionHandler(graph: graph,
                                   node: node,
                                   position: position,
                                   zIndex: zIndex,
                                   usePositionHandler: usePositionHandler)
        .opacity(isHiddenDuringAnimation ? 0 : 1)
    }

    @MainActor
    var nodeBody: some View {
        VStack(alignment: .leading, spacing: .zero) {
            nodeTitle
            
            CanvasItemBodyDivider()
            
            nodeBodyKind
                .modifier(CanvasItemBodyPadding())
        }
        .fixedSize()
        .modifier(CanvasItemBackground(color: nodeUIColor.body))
        .modifier(CanvasItemBoundsReader(
            graph: graph,
            canvasItem: node,
            splitterType: splitterType,
            disabled: boundsReaderDisabled,
            updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds))
        
        .modifier(CanvasItemSelectedViewModifier(isSelected: isSelected))
    }

    var nodeTitle: some View {
        
        HStack {
            CanvasItemTitleView(graph: graph,
                                node: stitch,
                                isNodeSelected: isSelected,
                                canvasId: node.id)
            .modifier(CanvasItemTitlePadding())
            
            Spacer()
            CanvasItemTag(isSelected: isSelected,
                          nodeTagMenu: nodeTagMenu)
//            Menu {
//                nodeTagMenu
//            } label: {
//                Image(systemName: "ellipsis.rectangle")
//            }
//            .buttonStyle(.plain)
//            .scaleEffect(1.4)
//            .frame(width: 24, height: 12)
//            .foregroundColor(STITCH_TITLE_FONT_COLOR)
//            .padding(.trailing, 8) // 8 from right edge, per Figma
            
        }
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
                               node: stitch,
                               canvasItemId: node.id,
                               activeGroupId: activeGroupId,
                               nodeTypeChoices: sortedUserTypeChoices,
                               canAddInput: canAddInput,
                               canRemoveInput: canRemoveInput,
                               atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                               // Always false for PatchNodeView
                               isHiddenLayer: false)
    }
}

//struct NodeView_REPL: View {
//
//    let devPosition = StitchPosition(width: 500,
//                                     height: 500)
//
//    var body: some View {
//        ZStack {
//            //            Color.orange.opacity(0.2).zIndex(-2)
//
//            FakeNodeView(
//                node: Patch.add.getFakePatchNode(
//                    //                    customName: "A very long name, much tested and loved and feared and enjoyed"
//                    customName: "A very long name"
//                )!
//            )
//
//        }
//        .scaleEffect(2)
//        //        .offset(y: -500)
//    }
//}

// struct FakeNodeView: View {

//     let node: NodeViewModel

//     var body: some View {
//         NodeTypeView(graph: .init(id: .init(), store: nil),
//                      node: node,
//                      atleastOneCommentBoxSelected: false,
//                      activeIndex: .init(1),
//                      groupNodeFocused: nil,
//                      adjustmentBarSessionId: .init(id: .fakeId),
//                      boundsReaderDisabled: true,
//                      usePositionHandler: false,
//                      updateMenuActiveSelectionBounds: false)
//     }
// }

// extension GraphState {
//     @MainActor
//     static let fakeEmptyGraphState: GraphState = .init(id: .init(), store: nil)
// }

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

//#Preview {
//    FakeNodeView(node: getFakeNode(choice: .patch(.add))!)
//}

struct CanvasItemBodyDivider: View {
    var body: some View {
        Divider().height(1)
    }
}

struct CanvasItemTitlePadding: ViewModifier {
    func body(content: Content) -> some View {
        // Figma: 8 padding on left, 12 padding on top and bottom
        content
            .padding(.leading, 8)
//            .padding(.trailing, 64) // enough distance from canvas item menu icon
//            .padding(.trailing, 32) // enough distance from canvas item menu icon
            .padding(.trailing, 16) // enough distance from canvas item menu icon
            .padding([.top, .bottom], 12)
    }
}

struct CanvasItemBodyPadding: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.top, 8)
            .padding(.bottom, NODE_BODY_PADDING + 4)
    }
}

struct CanvasItemBackground: ViewModifier {
    
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                    color.opacity(0.1)
//                    color.opacity(0.3)
                    //                nodeUIColor.body.opacity(0.5)
                    //                nodeUIColor.body.opacity(0.7)
                }
                .cornerRadius(CANVAS_ITEM_CORNER_RADIUS)
            }
    }
}

struct CanvasItemTag: View {
    
    let isSelected: Bool
    let nodeTagMenu: NodeTagMenuButtonsView
    
    var body: some View {
        
            Menu {
                nodeTagMenu
            } label: {
                let iconName = "ellipsis.rectangle"
                //                        let iconName = "ellipsis.circle"
                Image(systemName: iconName)
                
#if !targetEnvironment(macCatalyst)
                    .padding(16) // increase hit area
#endif
            }
        
#if targetEnvironment(macCatalyst)
            .buttonStyle(.plain)
            .scaleEffect(1.4)
            .frame(width: 24, height: 12)
            .foregroundColor(STITCH_TITLE_FONT_COLOR)
            .padding(.trailing, 8)
#else
            // iPad
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .foregroundColor(STITCH_TITLE_FONT_COLOR)
#endif
            .opacity(isSelected ? 1 : 0)
    }
}

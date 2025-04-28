//
//  NodeView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import UIKit
import StitchSchemaKit

struct NodeView: View {
    @Bindable var node: CanvasItemViewModel
    @Bindable var stitch: NodeViewModel
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let nodeId: NodeId
    let isSelected: Bool
    let atleastOneCommentBoxSelected: Bool
    let activeGroupId: GroupNodeType?
    let canAddInput: Bool
    let canRemoveInput: Bool

    let boundsReaderDisabled: Bool
    let updateMenuActiveSelectionBounds: Bool

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
    
    var isLayerNode: Bool {
        self.stitch.kind.isLayer
    }

    var body: some View {
        NodeLayout(observer: node,
                   existingCache: node.viewCache) {
            nodeBody
                .opacity(node.viewCache.isDefined ? 1 : 0)
            .onAppear {
                self.node.updateVisibilityStatus(with: true, graph: graph)
            }
            .onDisappear {
                self.node.updateVisibilityStatus(with: false, graph: graph)
            }
            .onChange(of: self.isSelected) {
            // // TODO: if I rely on e.g. graph.selectedEdges in this closure, would that force a render-cycle vs dispatching the action?
            // node.updateObserversPortColorsAndConnectedCanvasItemsCache(selectedEdges: graph.selectedEdges, drawingObserver: graph.edgeDrawingObserver)
                
                dispatch(UpdatePortColorUponNodeSelected(nodeId: nodeId))
            }
#if targetEnvironment(macCatalyst)
            // Catalyst right-click to open canvas item menu
                .contextMenu {
                    CanvasItemMenuButtonsView(graph: graph,
                                           document: document,
                                           node: stitch,
                                           canvasItemId: node.id,
                                           activeGroupId: activeGroupId,
                                           canAddInput: canAddInput,
                                           canRemoveInput: canRemoveInput,
                                           atleastOneCommentBoxSelected: atleastOneCommentBoxSelected)
                }
#endif
                .modifier(
                    NodeViewTapGestureModifier(graph: graph,
                                               document: document,
                                               stitch: stitch,
                                               node: node)
                )
            
            /*
             Note: every touch on a part of a node is an interaction (e.g. the title, an input field etc.) with a single node --- except for touching the node tag menu.
             
             So, we must .overlay the node tag menu *after* the tap-gestures, so that tapping the node tag menu does not fire a single-tap.
             
             (This would not be required if TapGesture were not .simultaneous, but that is required for handling both single- and double-taps.)
             */
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        CanvasItemTag(node: node,
                                      graph: graph,
                                      document: document,
                                      stitch: stitch,
                                      activeGroupId: activeGroupId,
                                      canAddInput: canAddInput,
                                      canRemoveInput: canRemoveInput,
                                      atleastOneCommentBoxSelected: atleastOneCommentBoxSelected)
                    }
                }
                .modifier(CanvasItemInputChangeHandleViewModier(
                    scale: document.graphMovement.zoomData,
                    nodeId: self.nodeId,
                    canAddInput: canAddInput,
                    nodeBodyHovered: $nodeBodyHovered))
        }
                   .modifier(CanvasItemPositionHandler(document: document,
                                                       graph: graph,
                                                       node: node,
                                                       zIndex: zIndex))
    }
    
    @State private var nodeBodyHovered: Bool = false
    
    @MainActor
    var nodeBody: some View {
        VStack(alignment: .leading, spacing: .zero) {
            nodeTitle
            
            CanvasItemBodyDivider()
            
            nodeBodyKind
                .modifier(CanvasItemBodyPadding())
        }
        .onChange(of: self.node.sizeByLocalBounds) {
            // also a useful hack for updating node layout after type changes
            self.node.updateAnchorPoints()
        }
        .overlay {
            let isLayerInvisible = !(stitch.layerNode?.hasSidebarVisibility ?? true)
            Color.black.opacity(isLayerInvisible ? 0.3 : 0)
                .cornerRadius(CANVAS_ITEM_CORNER_RADIUS)
                .allowsHitTesting(!isLayerInvisible)
        }
        .overlay {
            if document.llmRecording.mode == .augmentation &&
                document.llmRecording.modal == .editBeforeSubmit {
                let isAICreated = document.llmRecording.actions.containsNewNode(from: stitch.id)
                Color.blue.opacity(isAICreated ? 0.2 : 0)
                    .cornerRadius(CANVAS_ITEM_CORNER_RADIUS)
                    .allowsHitTesting(!isAICreated)
            }
        }
        .modifier(CanvasItemBackground(color: nodeUIColor.body))
        
        .modifier(CanvasItemSelectedViewModifier(isSelected: isSelected))
        .onHover { isHovering in
            self.nodeBodyHovered = isHovering
        }
    }

    var nodeTitle: some View {
        
        HStack {
            CanvasItemTitleView(document: document,
                                graph: graph,
                                node: stitch,
                                canvasItem: node,
                                isCanvasItemSelected: isSelected)
            .modifier(CanvasItemTitlePadding())
            
            Spacer()
        }
    }

    var nodeBodyKind: some View {
        HStack(alignment: .top, spacing: NODE_BODY_SPACING) {
            inputsViews()
            Spacer()
            outputsViews()
        }
    }
    
    @ViewBuilder @MainActor
    func inputsViews() -> some View {
        VStack(alignment: .leading,
               spacing: SPACING_BETWEEN_NODE_ROWS) {
            if self.stitch.patch == .wirelessReceiver {
                WirelessPortView(isOutput: false, id: stitch.id)
                    .padding(.trailing, NODE_BODY_SPACING)
            } else if let layerNode: LayerNodeViewModel = self.stitch.layerNode,
                      let layerInputCoordinate: LayerInputCoordinate = self.node.id.layerInputCase {
                // Layer input or field
                CanvasLayerInputViewWrapper(graph: graph,
                                            document: document,
                                            node: stitch,
                                            canvasNode: node,
                                            layerNode: layerNode,
                                            layerInputCoordinate: layerInputCoordinate,
                                            isNodeSelected: isSelected)
            }  else {
                // Multiple inputs
                DefaultNodeInputsView(graph: graph,
                                      document: document,
                                      node: stitch,
                                      canvas: node,
                                      isNodeSelected: isSelected)
            }
        }
    }
    
    @ViewBuilder @MainActor
    func outputsViews() -> some View {
        VStack(alignment: .trailing,
               spacing: SPACING_BETWEEN_NODE_ROWS) {
            
            if self.stitch.patch == .wirelessBroadcaster {
                WirelessPortView(isOutput: true, id: stitch.id)
                    .padding(.leading, NODE_BODY_SPACING)
            } else {
                DefaultNodeOutputsView(graph: graph,
                                       document: document,
                                       node: stitch,
                                       canvas: node)
            }
        }
    }
}

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
        
#if targetEnvironment(macCatalyst)
            .padding(.trailing, 40) // enough distance from canvas item menu icon
#else
        //            .padding(.trailing, 64) // enough distance from canvas item menu icon
            .padding(.trailing, 52) // enough distance from canvas item menu icon
#endif
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
                    VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                    .cornerRadius(CANVAS_ITEM_CORNER_RADIUS).overlay {
                        color.opacity(0.3)
                            .cornerRadius(CANVAS_ITEM_CORNER_RADIUS)
                    }
                //                    color.opacity(0.1)
                //                nodeUIColor.body.opacity(0.5)
                //                nodeUIColor.body.opacity(0.7)
            }
            
    }
}

struct CanvasItemTag: View {
    @Bindable var node: CanvasItemViewModel
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var stitch: NodeViewModel
    let activeGroupId: GroupNodeType?
    let canAddInput: Bool
    let canRemoveInput: Bool
    let atleastOneCommentBoxSelected: Bool
    
    // fka `nodeTagMenu`
    @ViewBuilder var canvasItemMenu: CanvasItemMenuButtonsView {
        CanvasItemMenuButtonsView(graph: graph,
                               document: document,
                               node: stitch,
                               canvasItemId: node.id,
                               activeGroupId: activeGroupId,
                               canAddInput: canAddInput,
                               canRemoveInput: canRemoveInput,
                               atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                               loopIndices: self.loopIndices)
    }
    
    @MainActor
    var loopIndices: [Int]? {
        // MARK: very important to process this outside of NodeTagMenuButtonsView: doing so fixes a bug where the node type menu becomes unresponsive if values are constantly changing on iPad.
#if targetEnvironment(macCatalyst)
        nil
#else
        self.stitch.getLoopIndices()
#endif
    }
    
    var body: some View {
        
            Menu {
                canvasItemMenu
            } label: {
                let iconName = "ellipsis.rectangle"
                Image(systemName: iconName)
#if !targetEnvironment(macCatalyst)
                    .padding(16) // increase hit area
#else
                    .padding(8)
#endif
            }
        
#if targetEnvironment(macCatalyst)
            .buttonStyle(.plain)
            .scaleEffect(1.4)
            .frame(width: 24, height: 12)
            .foregroundColor(STITCH_TITLE_FONT_COLOR)
            .padding(.trailing, 8)
            .offset(x: -16, y: 22)
#else
            // iPad
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .foregroundColor(STITCH_TITLE_FONT_COLOR)
            .offset(x: -16, y: 4)
#endif
    }
}

// Note: we prefer not to use .simultaneousGesture for node tap unless absolutely necessary, since
// TODO: perf implications of this view
struct NodeViewTapGestureModifier: ViewModifier {
    
    let graph: GraphState
    let document: StitchDocumentViewModel
    let stitch: NodeViewModel
    let node: CanvasItemViewModel
    
    var isGroup: Bool {
        self.stitch.kind.isGroup
    }

    func onSingleTap() {
        // deselect any fields; NOTE: not used on GroupNodes due to .simultaneousGesture
        if !self.stitch.kind.isGroup,
           document.reduxFocusedField != nil {
            document.reduxFocusedField = nil
        }
        
        // and select just the node
        document.canvasItemTapped(node)
    }
    
    func onDoubleTap() {
        graph.groupNodeDoubleTapped(id: stitch.id,
                                    document: document)
    }
    
    func body(content: Content) -> some View {
        /*
         Note: we must order these gestures as `double tap gesture -> single tap simultaneous gesture`.
         
         If both gestures are simultaneous, then a "double tap" user gesture ends up doing a single tap then a double tap then ANOTHER single tap.
         
         If both gestures non-simultaneous, then there is a delay as SwiftUI waits to see whether we did a single or a double tap.
         */
        if isGroup {
            content
                .gesture(TapGesture(count: 2).onEnded({
                    onDoubleTap()
                }))
                .simultaneousGesture(TapGesture(count: 1).onEnded({
                    onSingleTap()
                }))
        } else {
            content
                .onTapGesture {
                    onSingleTap()
                }
        }
    }
}

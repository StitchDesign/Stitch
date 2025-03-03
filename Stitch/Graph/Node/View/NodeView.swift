//
//  NodeView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import UIKit
import StitchSchemaKit

struct NodeView<InputsViews: View, OutputsViews: View>: View {
    @Bindable var node: CanvasItemViewModel
    @Bindable var stitch: NodeViewModel
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    let nodeId: NodeId
    let isSelected: Bool
    let atleastOneCommentBoxSelected: Bool
    let activeGroupId: GroupNodeType?
    let canAddInput: Bool
    let canRemoveInput: Bool

    // Only for patch nodes
    var sortedUserTypeChoices: [UserVisibleType] = []

    let boundsReaderDisabled: Bool
    let usePositionHandler: Bool
    let updateMenuActiveSelectionBounds: Bool    

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
    
    var isLayerNode: Bool {
        self.stitch.kind.isLayer
    }

    var body: some View {
        NodeLayoutView(observer: node) {
            nodeBody
                .opacity(node.viewCache.isDefined ? 1 : 0)
            .onAppear {
                self.node.updateVisibilityStatus(with: true, graph: graph)
            }
            .onDisappear {
                self.node.updateVisibilityStatus(with: false, graph: graph)
            }
            .onChange(of: self.isSelected) {
                self.stitch.updatePortColorDataUponNodeSelection()
            }
#if targetEnvironment(macCatalyst)
            // Catalyst right-click to open node tag menu
                .contextMenu {
                    NodeTagMenuButtonsView(graph: graph,
                                           graphUI: graphUI,
                                           document: document,
                                           node: stitch,
                                           canvasItemId: node.id,
                                           activeGroupId: activeGroupId,
                                           nodeTypeChoices: sortedUserTypeChoices,
                                           canAddInput: canAddInput,
                                           canRemoveInput: canRemoveInput,
                                           atleastOneCommentBoxSelected: atleastOneCommentBoxSelected)
                }
#endif
                .modifier(
                    NodeViewTapGestureModifier(graph: graph,
                                               document: document,
                                               graphUI: graphUI,
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
                                      graphUI: graphUI,
                                      document: document,
                                      stitch: stitch,
                                      activeGroupId: activeGroupId,
                                      sortedUserTypeChoices: sortedUserTypeChoices,
                                      canAddInput: canAddInput,
                                      canRemoveInput: canRemoveInput,
                                      atleastOneCommentBoxSelected: atleastOneCommentBoxSelected)
                    }
                }
        }
        .canvasItemPositionHandler(document: document,
                                   node: node,
                                   zIndex: zIndex,
                                   usePositionHandler: usePositionHandler)
    }

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
            self.node.updatePortLocations()
        }
        .overlay {
            let isLayerInvisible = !(stitch.layerNode?.hasSidebarVisibility ?? true)
            Color.black.opacity(isLayerInvisible ? 0.3 : 0)
                .cornerRadius(CANVAS_ITEM_CORNER_RADIUS)
                .allowsHitTesting(!isLayerInvisible)
        }
        .overlay {
            if graph.llmRecording.mode == .augmentation &&
                document.llmRecording.modal == .editBeforeSubmit {
                let isAICreated = graph.llmRecording.actions.containsNewNode(from: stitch.id)
                Color.blue.opacity(isAICreated ? 0.2 : 0)
                    .cornerRadius(CANVAS_ITEM_CORNER_RADIUS)
                    .allowsHitTesting(!isAICreated)
            }
        }
        .modifier(CanvasItemBackground(color: nodeUIColor.body))
        
        .modifier(CanvasItemSelectedViewModifier(isSelected: isSelected))
    }

    var nodeTitle: some View {
        
        HStack {
            CanvasItemTitleView(document: document,
                                graph: graph,
                                graphUI: graphUI,
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
}

@MainActor
func getFakeNode(choice: NodeKind,
                 _ nodePosition: CGSize = .zero,
                 _ zIndex: ZIndex = 1,
                 customName: String? = nil) -> NodeViewModel? {

    let document = StitchDocumentViewModel.createEmpty()
    
    if let node = document.nodeCreated(choice: choice) {
                
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
    @Bindable var graphUI: GraphUIState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var stitch: NodeViewModel
    let activeGroupId: GroupNodeType?
    var sortedUserTypeChoices: [UserVisibleType] = []
    let canAddInput: Bool
    let canRemoveInput: Bool
    let atleastOneCommentBoxSelected: Bool
    
    @ViewBuilder var nodeTagMenu: NodeTagMenuButtonsView {
        NodeTagMenuButtonsView(graph: graph,
                               graphUI: graphUI,
                               document: document,
                               node: stitch,
                               canvasItemId: node.id,
                               activeGroupId: activeGroupId,
                               nodeTypeChoices: sortedUserTypeChoices,
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
                nodeTagMenu
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
    let graphUI: GraphUIState
    let stitch: NodeViewModel
    let node: CanvasItemViewModel
    
    var isGroup: Bool {
        self.stitch.kind.isGroup
    }

    func onSingleTap() {
        // deselect any fields; NOTE: not used on GroupNodes due to .simultaneousGesture
        if !self.stitch.kind.isGroup,
           graphUI.reduxFocusedField != nil {
            graphUI.reduxFocusedField = nil
        }
        
        // and select just the node
        node.isTapped(document: document,
                      graphUI: graphUI)
    }
    
    func onDoubleTap() {
        graph.groupNodeDoubleTapped(id: stitch.id,
                                    graphUI: graphUI)
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

//
//  NodeView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import UIKit
import StitchSchemaKit

struct CacheData {
    let maxSize: CGSize
    let spacing: [CGFloat]
    let totalSpacing: CGFloat
}

struct InfiniteCanvas: Layout {
    let graph: GraphState
    let viewFrameSize: CGSize
    let origin: CGPoint
    let zoom: Double
    
    typealias Cache = [CanvasItemId: CGRect]
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        .init(width: proposal.width ?? .zero,
              height: proposal.height ?? .zero)
    }
    
    @MainActor
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        var visibleNodes = Set<CanvasItemId>()
        
        let viewframeOrigin = CGPoint(x: -origin.x,
                                      y: -origin.y)
        
        let graphView = CGRect(origin: viewframeOrigin,
                               size: viewFrameSize)
        let viewframe = Self.getScaledViewFrame(scale: 1 / zoom,
                                                graphView: graphView)
        
        
        for index in subviews.indices {
            let subview = subviews[index]
            let id = subview[CanvasIdKey.self]

//            let subviewSize = subview.sizeThatFits(proposal)
//            
////            guard let position = subview[CanvasPositionKey.self] else {
////                subview.place(
////                    at: bounds.origin,
////                    anchor: .topLeading,
////                    proposal: ProposedViewSize(subviewSize))
////                continue
////            }
//            
//            
//            guard let canvasItem = self.graph.getCanvasItem(id) else {
//                fatalError()
//            }
//            
//            // Update size data
//            // TODO: definitely not correct position
//            canvasItem.bounds.localBounds = .init(origin: canvasItem.position,
//                                                  size: subviewSize)

            let subviewSize = cache.get(id)?.size ?? subview.sizeThatFits(proposal)
            
            subview.place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(subviewSize))
            
            // TODO: can we remove isVisibleInFrame
//            if isVisibleInFrame != canvasItem.isVisibleInFrame {
//                canvasItem.isVisibleInFrame = isVisibleInFrame
//            }
        }
        
        for canvasItem in graph.visibleNodesViewModel.allViewModels {
            guard let size = cache.get(canvasItem.id)?.size else { continue }
            
            let isVisibleInFrame = viewframe.intersects(.init(origin: canvasItem.position,
                                                              size: size))
            
            canvasItem.updateVisibilityStatus(with: isVisibleInFrame)
            
            if isVisibleInFrame && canvasItem.parentGroupNodeId == graph.graphUI.groupNodeFocused?.groupNodeId {
//                log("visibile test: in frame")
                
                
                visibleNodes.insert(canvasItem.id)
            }
        }
        
        if graph.visibleNodesViewModel.visibleCanvasIds != visibleNodes {
            graph.visibleNodesViewModel.visibleCanvasIds = visibleNodes
        }
    }
    
    /// Uses graph local offset and scale to get a modified `CGRect` of the view frame.
    static func getScaledViewFrame(scale: Double,
                                   graphView: CGRect) -> CGRect {
        let scaledSize = CGSize(
            width: graphView.width * scale,
            height: graphView.height * scale)

        let yDiff = (graphView.height - scaledSize.height) / 2
        let xDiff = (graphView.width - scaledSize.width) / 2
        
        return CGRect(origin: CGPoint(x: graphView.origin.x + xDiff,
                                      y: graphView.origin.y + yDiff),
                      size: scaledSize)
    }
    
    @MainActor
    func makeCache(subviews: Subviews) -> Cache {
        subviews.reduce(into: Cache()) { result, subview in
            let id = subview[CanvasIdKey.self]
            let size = subview.sizeThatFits(.unspecified)
            
            // TODO: make position key again?
            guard let canvasItem = self.graph.getCanvasItem(id) else {
                fatalError()
            }
            
            let bounds = CGRect(origin: canvasItem.position,
                                size: size)
            result.updateValue(bounds, forKey: id)
        }
    }
    
    func updateCache(_ cache: inout Cache, subviews: Subviews) {
//        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }
}

private struct CanvasIdKey: LayoutValueKey {
    static let defaultValue: CanvasItemId = .node(.init())
}

extension View {
    func canvasId(_ id: CanvasItemId) -> some View {
        layoutValue(key: CanvasIdKey.self, value: id)
    }
}

struct NodeLayout: Layout {
    let node: CanvasItemViewModel
    
    struct Cache {
        var sizes: [CGSize] = []
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        .init(width: proposal.width ?? .zero,
              height: proposal.height ?? .zero)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard !subviews.isEmpty else { return }
        
        for index in subviews.indices {
            let subview = subviews[index]
//            let size = subview.sizeThatFits(proposal)
            let size = cache.sizes[index]
            
            subview.place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(size))
            //            nextX += maxSize.width + spacing[index]
        }
    }
    
    private func maxSize(subviews: Subviews) -> CGSize {
        let subviewSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxSize: CGSize = subviewSizes.reduce(.zero) { currentMax, subviewSize in
            CGSize(
                width: max(currentMax.width, subviewSize.width),
                height: max(currentMax.height, subviewSize.height))
        }
        
        return maxSize
    }
    
    func makeCache(subviews: Subviews) -> Cache {
        guard let cachedSizes = node.subviewSizes else {
            let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            self.node.subviewSizes = sizes
            return Cache(sizes: sizes)
        }
        
        return Cache(sizes: cachedSizes)
    }
    
    func updateCache(_ cache: inout Cache, subviews: Subviews) {
//        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }
    
    func explicitAlignment(of guide: HorizontalAlignment,
                           in bounds: CGRect,
                           proposal: ProposedViewSize,
                           subviews: Self.Subviews,
                           cache: inout Cache) -> CGFloat? {
        return nil
    }
    
    func explicitAlignment(of guide: VerticalAlignment,
                           in bounds: CGRect,
                           proposal: ProposedViewSize,
                           subviews: Self.Subviews,
                           cache: inout Cache) -> CGFloat? {
        return nil
    }
}


struct NodeView<InputsViews: View, OutputsViews: View>: View {
    @Bindable var node: CanvasItemViewModel
    @Bindable var stitch: NodeViewModel
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
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
        NodeLayout(node: node) {
            nodeBody
#if targetEnvironment(macCatalyst)
            // Catalyst right-click to open node tag menu
                .contextMenu {
                    NodeTagMenuButtonsView(graph: graph,
                                           node: stitch,
                                           canvasItemId: node.id,
                                           activeGroupId: activeGroupId,
                                           nodeTypeChoices: sortedUserTypeChoices,
                                           canAddInput: canAddInput,
                                           canRemoveInput: canRemoveInput,
                                           atleastOneCommentBoxSelected: atleastOneCommentBoxSelected)
                }
#endif
                .modifier(NodeViewTapGestureModifier(
                    onSingleTap: {
                        // deselect any fields; NOTE: not used on GroupNodes due to .simultaneousGesture
                        if !self.stitch.kind.isGroup {
                            graph.graphUI.reduxFocusedField = nil
                        }
                        
                        // and select just the node
                        node.isTapped(document: document)
                    },
                    onDoubleTap: {
                        dispatch(GroupNodeDoubleTapped(id: stitch.id))
                    },
                    isGroup: self.stitch.kind.isGroup))
            
            /*
             Note: every touch on a part of a node is an interaction (e.g. the title, an input field etc.) with a single node --- except for touching the node tag menu.
             
             So, we must .overlay the node tag menu *after* the tap-gestures, so that tapping the node tag menu does not fire a single-tap.
             
             (This would not be required if TapGesture were not .simultaneous, but that is required for handling both single- and double-taps.)
             */
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        CanvasItemTag(node: node,
                                      graph: graph,
                                      stitch: stitch,
                                      activeGroupId: activeGroupId,
                                      sortedUserTypeChoices: sortedUserTypeChoices,
                                      canAddInput: canAddInput,
                                      canRemoveInput: canRemoveInput,
                                      atleastOneCommentBoxSelected: atleastOneCommentBoxSelected)
                    }
                }
                .canvasItemPositionHandler(document: document,
                                           node: node,
                                           zIndex: zIndex,
                                           usePositionHandler: usePositionHandler)
        }
    }

    @MainActor
    var nodeBody: some View {
        VStack(alignment: .leading, spacing: .zero) {
            nodeTitle
            
            CanvasItemBodyDivider()
            
            nodeBodyKind
                .modifier(CanvasItemBodyPadding())
        }
        .overlay {
            let isLayerInvisible = !(stitch.layerNode?.hasSidebarVisibility ?? true)
            Color.black.opacity(isLayerInvisible ? 0.3 : 0)
                .cornerRadius(CANVAS_ITEM_CORNER_RADIUS)
                .allowsHitTesting(!isLayerInvisible)
        }
        .fixedSize()
        .modifier(CanvasItemBackground(color: nodeUIColor.body))
//        .modifier(CanvasItemBoundsReader(
//            graph: graph,
//            canvasItem: node,
//            disabled: boundsReaderDisabled,
//            updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds))
        
        .modifier(CanvasItemSelectedViewModifier(isSelected: isSelected))
    }

    var nodeTitle: some View {
        
        HStack {
            CanvasItemTitleView(graph: graph,
                                node: stitch,
                                isCanvasItemSelected: isSelected,
                                canvasId: node.id)
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
    @Bindable var stitch: NodeViewModel
    let activeGroupId: GroupNodeType?
    var sortedUserTypeChoices: [UserVisibleType] = []
    let canAddInput: Bool
    let canRemoveInput: Bool
    let atleastOneCommentBoxSelected: Bool
    
    @ViewBuilder var nodeTagMenu: NodeTagMenuButtonsView {
        NodeTagMenuButtonsView(graph: graph,
                               node: stitch,
                               canvasItemId: node.id,
                               activeGroupId: activeGroupId,
                               nodeTypeChoices: sortedUserTypeChoices,
                               canAddInput: canAddInput,
                               canRemoveInput: canRemoveInput,
                               atleastOneCommentBoxSelected: atleastOneCommentBoxSelected)
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
    
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let isGroup: Bool

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

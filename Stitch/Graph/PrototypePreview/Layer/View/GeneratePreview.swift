//
//  GeneratePreview.swift
//  prototype
//
//  Created by Christian J Clampitt on 10/20/21.
//

import SwiftUI
import StitchSchemaKit


/// The top-level preview window view encompassing all views.
struct GeneratePreview: View {
    @Bindable var document: StitchDocumentViewModel
    
    @MainActor
    var sortedLayerDataList: LayerDataList {
        // see `GraphState.updateOrderedPreviewLayers()`
        document.graph.cachedOrderedPreviewLayers
    }
    
    var body: some View {
        // Regular rendering of views in their proper place in the hierarchy
        PreviewLayersView(document: document,
                          graph: document.graph,
                          layers: sortedLayerDataList,
                          parentSize: document.previewWindowSize,
                          parentId: nil,
                          parentOrientation: .none,
                          parentPadding: .zero,
                          parentSpacing: .zero,
                          parentCornerRadius: 0,
                          parentUsesHug: false,
                          parentGridData: nil,
                          isGhostView: false)
        .background {
            // Invisible views used for reporting pinning position data
            PreviewLayersView(document: document,
                              graph: document.graph,
                              layers: sortedLayerDataList,
                              parentSize: document.previewWindowSize,
                              parentId: nil,
                              parentOrientation: .none,
                              parentPadding: .zero,
                              parentSpacing: .zero,
                              parentCornerRadius: 0,
                              parentUsesHug: false,
                              parentGridData: nil,
                              isGhostView: true)
            .hidden()
            .disabled(true)
        }
        // Top-level coordinate space of preview window; for pinning
        .coordinateSpace(name: PREVIEW_WINDOW_COORDINATE_SPACE)
        
        .modifier(HoverGestureModifier(document: document,
                                       previewWindowSize: document.previewWindowSize))
    }
}

/// Similar to `GeneratePreview` but can be called recursively for group layers.
struct PreviewLayersView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let layers: LayerDataList
        
    /*
     When `PreviewLayersView` called from top-level:
     -- `parentSize` is preview window size
     
     When called from a group layer:
     -- `parentSize` is group layer's size (unscaled)
     */
    let parentSize: CGSize
    
    // Non-nil and non-zero when this view called by GroupLayer
    let parentId: LayerNodeId?
    
    // Are we a ZStack, an HStack, a VStack or an Adaptive Grid?
    var parentOrientation: StitchOrientation // = .none
    
    // Padding on the children overall
    var parentPadding: StitchPadding // = .init()
    
    // Spacing between the children; N/A for ZStack
    var parentSpacing: StitchSpacing // = .defaultStitchSpacing
    
    let parentCornerRadius: CGFloat
    let parentUsesHug: Bool
    let parentGridData: PreviewGridData?
    let isGhostView: Bool
    
     /*
      Note: [.red, .yellow, .black] in a ZStack places black "on top" (i.e. highest z-index), in a VStack places black "last"; i.e. ZStack and VStack/HStack have opposite expectations about ordering.
    
      Our sorting algorithm `recursivePreviewLayers` (and for a loop's layer view models) assumes `ZStack`; hence the need to reverse the sorted list when
      
      TODO: what is perf impact of doing `.reversed()` in a computed var on a view?; alternatively, for pass: (1) pass `parentOrientation` during the sorting in `.recursivePreviewLayers`, or (2) step through the collection background in `ForEach(layers)`
      (1) seems best?
     */
    var presentedLayers: LayerDataList {
        if parentOrientation == .none {
            return layers
        } else {
            return layers
                .filter {
                    !$0.isPinned
                }
        }
    }
    
    var pinsInOrientationView: LayerDataList {
        guard parentOrientation != .none else {
            return []
        }
        
        return layers
            .filter {
                $0.isPinned
            }
    }
    
    var parentDisablesPosition: Bool {
        parentOrientation != .none
    }

    @ViewBuilder
    func layersAsViews(_ spacing: StitchSpacing) -> some View {
        
        // `spacing: .evenly` = one spacer before and after each element
        // `spacing: .between` = one spacer between elements
        
        if spacing.isEvenly {
            Spacer()
        }
        
        // `LayerDataId` distinguishes between { layerViewModel, pinnedView } and { layerViewModel, ghostView }
        ForEach(presentedLayers) { layerData in
            
            LayerDataView(document: document,
                          layerData: layerData,
                          parentSize: parentSize,
                          parentDisablesPosition: parentDisablesPosition,
                          isGhostView: isGhostView)
            
            if spacing.isEvenly {
                Spacer()
            } else if spacing.isBetween,
                      layerData.id != presentedLayers.last?.id {
                Spacer()
            }
            
        } // ForEach
    }
    
    var body: some View {
        Group {
            
            // If no layers, provide a fake SwiftUI view to allow .onContinuousHover for mouse patch nodes
            if layers.isEmpty {
                Rectangle().fill(.clear)
            }
            
            ZStack {
                // Note: we previously wrapped the HStack / VStack layer group orientations in a scroll-disabled ScrollView so that the children would touch,
                orientationFromParent
                    .padding(.top, parentPadding.top)
                    .padding(.bottom, parentPadding.bottom)
                    .padding(.leading, parentPadding.left)
                    .padding(.trailing, parentPadding.right)

                ForEach(pinsInOrientationView) { layerData in
                    LayerDataView(document: document,
                                  layerData: layerData,
                                  parentSize: parentSize,
                                  parentDisablesPosition: parentDisablesPosition,
                                  isGhostView: isGhostView)
                }
            }
            
        } // Group
        .modifier(LayerGroupInteractableViewModifier(
            hasLayerInteraction: graph.hasInteraction(parentId),
            cornerRadius: parentCornerRadius))
    }
    
    @MainActor @ViewBuilder
    var orientationFromParent: some View {
        switch parentOrientation {
        case .none:
            ZStack {
                layersAsViews(parentSpacing)
            }
        case .horizontal:
            HStack(spacing: parentSpacing.asPointSpacing) {
                layersAsViews(parentSpacing)
            }
        case .vertical:
            VStack(spacing: parentSpacing.asPointSpacing) {
                layersAsViews(parentSpacing)
            }
        case .grid:
            gridView
        }
    }
    
    @MainActor @ViewBuilder
    var gridView: some View {
        
        if let parentGridData = parentGridData {
            
            // We *must* provide a "minimum cell space" for an .adaptive LazyVGrid.
            // So we use the largest width.
            // TODO: perf implications of iterating through e.g. 900 views?
            let longestReadWidth = presentedLayers.max { d1, d2 in
                d1.layer.readSize.width < d2.layer.readSize.width
            }?.layer.readSize.width ?? .zero
            
            // logInView("gridView: longestReadWidth: \(longestReadWidth)")
            
            // Note: very important: `.adaptive(minimum: .zero)` causes SwiftUI to crash
            // TODO: why `30`? What other number to use instead? `1` ? Does it matter?
            let gridCellMinimumWidth = max(longestReadWidth, 30.0)
                            
            // logInView("gridView: gridCellMinimumWidth: \(gridCellMinimumWidth)")
            
            let adaptiveColumns: [GridItem] = [
                // one adaptive GridItem with LazyVStack = lay all the items out in a single row that snakes like a Z
                GridItem(
                    // .adaptive = we don't specify number of columns
                    // maximum = allow items to grow to this size; unspecified
                    .adaptive(minimum: gridCellMinimumWidth),
                    
                    // In a LazyVGrid, horizontal spacing between columns.
                    spacing: parentGridData.horizontalSpacingBetweenColumns.asPointSpacing,
                    
                    // Alignment of an item within the min/max allowed space.
                    // Only relevant when grid cell is larger than child's own size.
                    alignment: parentGridData.alignmentOfItemWithinGridCell)
            ]
            
            LazyVGrid(columns: adaptiveColumns,
                      // Only relevant LazyVGrid is wider than needed to accomodate all the columns.
                      alignment: parentGridData.horizontalAlignmentOfGrid,
                      
                      // In a LazyVGrid, vertical spacing between rows:
                      spacing: parentGridData.verticalSpacingBetweenRows.asPointSpacing) {
                layersAsViews(parentSpacing)
            }
            
        } else {
            // Should never have .grid orientation without PreviewGridData
            EmptyView().onAppear {
                fatalErrorIfDebug()
            }
        }
    }
}

struct LayerDataView: View {
    @Bindable var document: StitchDocumentViewModel
    let layerData: LayerData
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let isGhostView: Bool
    
    var body: some View {
        
        switch layerData {
            
            // TODO: will this be accurate when e.g. masked's loop count = 3 but masker's loop count = 5? Or vice-versa?
            // For "more masked views than maskers, just repeat the maskers"
            // For "more maskers than masked views, limit ourselves to masked (layer) view count"
        case .mask(masked: let maskedLayerDataList,
                   masker: let maskerLayerDataList):
            
            ForEach(maskedLayerDataList) { (maskedLayerData: LayerData) in
                
                if let maskedIndex = maskedLayerDataList.firstIndex(where: { $0.id == maskedLayerData.id }),
                   maskedIndex < maskerLayerDataList.endIndex {
                    let maskerLayerData: LayerData = maskerLayerDataList[maskedIndex]
                    
                    // Turn masked LayerData into a single view
                    let masked: some View = LayerDataView(
                        document: document,
                        layerData: maskedLayerData,
                        parentSize: parentSize,
                        parentDisablesPosition: parentDisablesPosition,
                        isGhostView: isGhostView)
                    
                    // Turn masker LayerData into a single view
                    let masker: some View = LayerDataView(
                        document: document,
                        layerData: maskerLayerData,
                        parentSize: parentSize,
                        parentDisablesPosition: parentDisablesPosition,
                        isGhostView: isGhostView)
                    
                    // Return
                    masked.mask(masker)
                } else {
                    EmptyView()
                }
            }
            
        case .nongroup(let layerViewModel, _):
            if let node = document.graph.getLayerNode(id: layerViewModel.id.layerNodeId.id),
               let layerNode = node.layerNode {
                NonGroupPreviewLayersView(document: document,
                                          layerNode: layerNode,
                                          layerViewModel: layerViewModel,
                                          isPinnedViewRendering: !isGhostView,
                                          parentSize: parentSize,
                                          parentDisablesPosition: parentDisablesPosition)
            } else {
                EmptyView()
            }
                        
        case .group(let layerViewModel, let childrenData, _):
            if let node = document.graph.getLayerNode(id: layerViewModel.id.layerNodeId.id),
               let layerNode = node.layerNode {
                GroupPreviewLayersView(document: document,
                                       layerNode: layerNode,
                                       layerViewModel: layerViewModel,
                                       childrenData: childrenData,
                                       isPinnedViewRendering: !isGhostView,
                                       parentSize: parentSize,
                                       parentDisablesPosition: parentDisablesPosition)
            } else {
                EmptyView()
            }
        } // switch
    }
}

struct NonGroupPreviewLayersView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var layerViewModel: LayerViewModel

    let isPinnedViewRendering: Bool
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    
    var body: some View {
        if layerNode.hasSidebarVisibility,
           let graph = layerNode.nodeDelegate?.graphDelegate as? GraphState {
            PreviewLayerView(document: document,
                             graph: graph,
                             layerViewModel: layerViewModel,
                             layer: layerNode.layer,
                             isPinnedViewRendering: isPinnedViewRendering,
                             parentSize: parentSize,
                             parentDisablesPosition: parentDisablesPosition)
        } else {
            EmptyView()
        }
    }
}

struct GroupPreviewLayersView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var layerNode: LayerNodeViewModel
    let layerViewModel: LayerViewModel
    let childrenData: LayerDataList
    let isPinnedViewRendering: Bool
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    
    var body: some View {
        if layerNode.hasSidebarVisibility,
           let graph = layerNode.nodeDelegate?.graphDelegate as? GraphState {
            GroupLayerNode.content(document: document,
                                   graph: graph,
                                   viewModel: layerViewModel,
                                   parentSize: parentSize,
                                   layersInGroup: childrenData,
                                   isPinnedViewRendering: isPinnedViewRendering,
                                   parentDisablesPosition: parentDisablesPosition)
        } else {
            EmptyView()
        }
    }
}

//
//  GeneratePreview.swift
//  prototype
//
//  Created by Christian J Clampitt on 10/20/21.
//

import SwiftUI
import StitchSchemaKit

// typealias PreviewZIndexMap = [PreviewCoordinate: CGFloat]

/// The top-level preview window view encompassing all views.
struct GeneratePreview: View {
    @Bindable var graph: GraphState
    
    var visibleNodes: VisibleNodesViewModel {
        graph.visibleNodesViewModel
    }

    var sortedLayerDataList: LayerDataList {
        // see `GraphState.updateOrderedPreviewLayers()`
        self.graph.cachedOrderedPreviewLayers
    }
    
    var body: some View {
        PreviewLayersView(graph: graph,
                          layers: sortedLayerDataList,
                          parentSize: graph.previewWindowSize, 
                          parentId: nil,
                          // Always false at top-level
                          parentCornerRadius: 0, 
                          parentUsesHug: false,
                          parentGridData: nil)
        .modifier(HoverGestureModifier(graph: graph,
                                       previewWindowSize: graph.previewWindowSize))
    }
}

/// Similar to `GeneratePreview` but can be called recursively for group layers.
struct PreviewLayersView: View {
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
    var parentOrientation: StitchOrientation = .none
    var parentOrientationPadding: CGFloat = .zero
    let parentCornerRadius: CGFloat
    let parentUsesHug: Bool
    
    let parentGridData: PreviewGridData?
    
     /*
      Note: [.red, .yellow, .black] in a ZStack places black "on top" (i.e. highest z-index), in a VStack places black "last"; i.e. ZStack and VStack/HStack have opposite expectations about ordering.
    
      Our sorting algorithm `recursivePreviewLayers` (and for a loop's layer view models) assumes `ZStack`; hence the need to reverse the sorted list when
      
      TODO: what is perf impact of doing `.reversed()` in a computed var on a view?; alternatively, for pass: (1) pass `parentOrientation` during the sorting in `.recursivePreviewLayers`, or (2) step through the collection background in `ForEach(layers)`
      (1) seems best?
     */
    var layersInProperOrder: LayerDataList {
        if parentOrientation == .none {
            return layers
        } else {
            return layers.reversed()
        }
    }
    
    var parentDisablesPosition: Bool {
        parentOrientation != .none
    }

    @ViewBuilder
    var layersAsViews: some View {
        ForEach(layersInProperOrder) { layerData in
            LayerDataView(graph: graph,
                          layerData: layerData,
                          parentSize: parentSize,
                          parentDisablesPosition: parentDisablesPosition)
        } // ForEach
    }
    
    var body: some View {
        Group {
            
            // If no layers, provide a fake SwiftUI view to allow .onContinuousHover for mouse patch nodes
            if layers.isEmpty {
                Rectangle().fill(.clear)
            }
            
            // Note: we previously wrapped the HStack / VStack layer group orientations in a scroll-disabled ScrollView so that the children would touch,
            orientationFromParent
            
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
                layersAsViews
            }
        case .horizontal:
            HStack(spacing: parentOrientationPadding) {
                layersAsViews
            }
        case .vertical:
            VStack(spacing: parentOrientationPadding) {
                layersAsViews
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
            let longestReadWidth = layersInProperOrder.max { d1, d2 in
                d1.layer.readSize.width < d2.layer.readSize.width
            }?.layer.readSize.width ?? .zero
            
            // logInView("gridView: longestReadWidth: \(longestReadWidth)")
            
            // Note: very important: `.adaptive(minimum: .zero)` causes SwiftUI to crash
            let gridCellMinimumWidth = max(longestReadWidth, 30.0)
                            
            // logInView("gridView: gridCellMinimumWidth: \(gridCellMinimumWidth)")
            
            let horizontalSpacingBetweenColumns = parentGridData.horizontalSpacingBetweenColumns
            let verticalSpacingBetweenRows = parentGridData.verticalSpacingBetweenRows
            let alignmentOfItemWithinGridCell = parentGridData.alignmentOfItemWithinGridCell
            let horizontalAlignmentOfGrid = parentGridData.horizontalAlignmentOfGrid
            
            let adaptiveColumns: [GridItem] = [
                // one adaptive GridItem with LazyVStack = lay all the items out in a single row that snakes like a Z
                GridItem(
                    // .adaptive = we don't specify number of columns
                    // maximum = allow items to grow to this size; unspecified
                    .adaptive(minimum: gridCellMinimumWidth),
                    
                    // In a LazyVGrid, horizontal spacing between columns.
                    spacing: horizontalSpacingBetweenColumns,
                    
                    // Alignment of an item within the min/max allowed space.
                    // Only relevant when grid cell is larger than child's own size.
                    alignment: alignmentOfItemWithinGridCell)
            ]
            
            LazyVGrid(columns: adaptiveColumns,
                      // Only relevant LazyVGrid is wider than needed to accomodate all the columns.
                      alignment: horizontalAlignmentOfGrid,
                      
                      // In a LazyVGrid, vertical spacing between rows:
                      spacing: verticalSpacingBetweenRows) {
                layersAsViews
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
    @Bindable var graph: GraphState
    let layerData: LayerData
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    
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
                        graph: graph,
                        layerData: maskedLayerData,
                        parentSize: parentSize,
                        parentDisablesPosition: parentDisablesPosition)
                    
                    // Turn masker LayerData into a single view
                    let masker: some View = LayerDataView(
                        graph: graph,
                        layerData: maskerLayerData,
                        parentSize: parentSize,
                        parentDisablesPosition: parentDisablesPosition)
                    
                    // Return
                    masked.mask(masker)
                } else {
                    EmptyView()
                }
            }
            
        case .nongroup(let layerViewModel):
            if let node = graph.getLayerNode(id: layerViewModel.id.layerNodeId.id),
               let layerNode = node.layerNode {
                NonGroupPreviewLayersView(graph: graph,
                                          layerNode: layerNode,
                                          layerViewModel: layerViewModel,
                                          parentSize: parentSize,
                                          parentDisablesPosition: parentDisablesPosition)
            } else {
                EmptyView()
            }
                        
        case .group(let layerViewModel,
                    let childrenData):
            
            if let node = graph.getLayerNode(id: layerViewModel.id.layerNodeId.id),
               let layerNode = node.layerNode {
                GroupPreviewLayersView(graph: graph,
                                       layerNode: layerNode,
                                       layerViewModel: layerViewModel,
                                       childrenData: childrenData,
                                       parentSize: parentSize,
                                       parentDisablesPosition: parentDisablesPosition)
            } else {
                EmptyView()
            }
        } // switch
    }
}

struct NonGroupPreviewLayersView: View {
    @Bindable var graph: GraphState
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var layerViewModel: LayerViewModel
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    
    var body: some View {
        if layerNode.hasSidebarVisibility {
            PreviewLayerView(graph: graph,
                             layerViewModel: layerViewModel,
                             layer: layerNode.layer,
                             parentSize: parentSize,
                             parentDisablesPosition: parentDisablesPosition)
        } else {
            EmptyView()
        }
    }
}

struct GroupPreviewLayersView: View {
    @Bindable var graph: GraphState
    @Bindable var layerNode: LayerNodeViewModel
    let layerViewModel: LayerViewModel
    let childrenData: LayerDataList
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    
    var body: some View {
        if layerNode.hasSidebarVisibility {
            GroupLayerNode.content(graph: graph,
                                   viewModel: layerViewModel,
                                   parentSize: parentSize,
                                   layersInGroup: childrenData,
                                   parentDisablesPosition: parentDisablesPosition)
        } else {
            EmptyView()
        }
    }
}

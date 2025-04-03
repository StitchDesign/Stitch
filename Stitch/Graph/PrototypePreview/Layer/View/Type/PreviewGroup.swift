//
//  PreviewGroup.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/4/21.
//

import SwiftUI
import StitchSchemaKit

extension LayerViewModel {
    @MainActor
    var getGridData: PreviewGridData? {
        guard self.layer.supportsSidebarGroup else {
            fatalErrorIfDebug()
            return nil
        }
        
        // TODO: update when StitchSpacing is added as a PortValue in schema
        let horizontalSpacingBetweenColumns = self.spacingBetweenGridColumns.getNumber.map { StitchSpacing.number($0) } ?? .defaultStitchSpacing
        
        let verticalSpacingBetweenRows = self.spacingBetweenGridRows.getNumber.map { StitchSpacing.number($0) } ?? .defaultStitchSpacing
        
        return .init(
            horizontalSpacingBetweenColumns: horizontalSpacingBetweenColumns,
            verticalSpacingBetweenRows: verticalSpacingBetweenRows,
            alignmentOfItemWithinGridCell: (self.itemAlignmentWithinGridCell.getAnchoring ?? .centerCenter).toAlignment
        )
    }
}

struct PreviewGroupLayer: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let realityContent: LayerRealityCameraContent?
    let layersInGroup: LayerDataList // child layers for THIS group
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    
    let position: CGPoint
    let size: LayerSize

    // Assumes parentSize has already been scaled, etc.
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool

    let isClipped: Bool
    let scale: CGFloat
    let anchoring: Anchoring

    var rotationX: CGFloat
    var rotationY: CGFloat
    var rotationZ: CGFloat

    let opacity: Double
    let pivot: Anchoring

    let orientation: StitchOrientation
    let spacing: StitchSpacing
    
    let cornerRadius: CGFloat
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    
    let backgroundColor: Color
    
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    
    let shadowColor: Color
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: StitchPosition
    
    let gridData: PreviewGridData?
    
    let stroke: LayerStrokeData
    
    var debugBorderColor: Color {
        #if DEV_DEBUG
        return .red
        #else
        return .clear
        #endif
    }

    var _size: CGSize {
        size.asCGSize(parentSize)
    }

    // TODO: what if only one dimension uses .hug ?
    var usesHug: Bool {
        size.width == .hug || size.height == .hug
    }
    
    var noFixedSizeForLayerGroup: Bool {
        size.width.noFixedSizeForLayerGroup || size.height.noFixedSizeForLayerGroup
    }
    
    var useParentSizeForAnchoring: Bool {
        usesHug && !parentDisablesPosition
    }
    
    var pos: StitchPosition {
        log("pos called for PreviewGroupLayer")
        return adjustPosition(
//            size: layerViewModel.readSize, // size.asCGSize(parentSize),
            size: size.asCGSize(parentSize),
//            size: size.asCGSizeForLayer(parentSize: parentSize,
//                                        readSize: layerViewModel.readSize),
            position: position,
            anchor: anchoring,
            parentSize: parentSize)
    }
    
    var strokeAdjustedCornerRadius: CGFloat {
        cornerRadius - (stroke.stroke == .outside ? stroke.width : 0)
    }
    
    var body: some View {

        groupLayer
        
        // TODO: add "child alignment" input on Group Layer node? or find some other solution for how a group with an orientation can position children that have static sizes
        // TODO: don't need this if we're using the "hug" case in `LayerGroupPositionModifier` ?
        
            .modifier(PreviewCommonSizeModifier(
                viewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                pinMap: graph.pinMap,
                aspectRatio: layerViewModel.getAspectRatioData(),
                size: size,
                minWidth: layerViewModel.getMinWidth,
                maxWidth: layerViewModel.getMaxWidth,
                minHeight: layerViewModel.getMinHeight,
                maxHeight: layerViewModel.getMaxHeight,
                parentSize: parentSize,
                sizingScenario: layerViewModel.getSizingScenario,
                
                // careful -- for a ZStack where layers use .topLeft
                
                // a layer group's 
                frameAlignment: .center //anchoring.toAlignment
            ))
//
////            .bac
//        //            // DEBUG ONLY
//        //        #if DEV_DEBUG
            .border(.red, width: 2)
//        //        #endif
//
//            .frame(width: _parentSize.width, height: _parentSize.height)
//            .border(.red, width: 2)
            .offset(x: parentPos.x, y: parentPos.y)
//
//            .modifier(PreviewCommonPositionModifier(
//                graph: graph,
//                viewModel: layerViewModel,
//                isPinnedViewRendering: isPinnedViewRendering,
//                parentDisablesPosition: parentDisablesPosition,
//                parentIsScrollableGrid: parentIsScrollableGrid,
//                parentSize: parentSize,
//                pos: pos))
        
    }

    var _parentSize: CGSize {
        CGSize(width: 200, height: 200)
    }
    var _childSize: CGSize {
        CGSize(width: 100, height: 100)
    }
    var previewSize: CGSize {
        document.previewWindowSize
    }
    
    var parentPos: CGPoint {
        adjustPosition(
            size: _parentSize,
            position: .zero,
            anchor: .topLeft,
            parentSize: previewSize)
    }
    
    @ViewBuilder
    private var groupLayer: some View {

        // THIS IS ALSO OKAY FOR POSITIONING OF THE CHILD
        //
       
        
        // parent
        ZStack {
            let childPos = adjustPosition(
                size: _childSize,
                position: .zero,
                anchor: .topLeft,
                parentSize: _parentSize)
            
            // child
            Ellipse().fill(.cyan)
                .frame(width: _childSize.width, height: _childSize.height)
                .offset(x: childPos.x, y: childPos.y)
        }
//        .frame(width: _parentSize.width, height: _parentSize.height)
//        .border(.red, width: 2)
//        .offset(x: parentPos.x, y: parentPos.y)
        
//            PreviewLayersView(document: document,
//                              graph: graph,
//                              layers: layersInGroup,
//                              // This Group's size will be the `parentSize` for the `layersInGroup`
//                              parentSize: _size,
//                              parentId: interactiveLayer.id.layerNodeId,
//                              parentOrientation: orientation,
//                              parentSpacing: spacing,
//                              parentGroupAlignment: layerViewModel.layerGroupAlignment.getAnchoring,
//                              parentUsesScroll: layerViewModel.isScrollXEnabled || layerViewModel.isScrollYEnabled,
//                              parentCornerRadius: cornerRadius,
//                              // i.e. if this view (a LayerGroup) uses .hug, then its children will not use their own .position values.
//                              parentUsesHug: usesHug,
//                              noFixedSizeForLayerGroup: noFixedSizeForLayerGroup,
//                              parentGridData: gridData,
//                              isGhostView: !isPinnedViewRendering,
//                              realityContent: realityContent)
    }
}

struct ClippedModifier: ViewModifier {

    let isClipped: Bool
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if isClipped {
            // clipped should come before any offset/position modifier,
            // so that it's affected by the offset/position modifier
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .clipped()
        } else {
            content
        }
    }
}

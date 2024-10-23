//
//  PreviewGroup.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/4/21.
//

import SwiftUI
import StitchSchemaKit

extension LayerViewModel {
    var getGridData: PreviewGridData? {
        guard self.layer == .group else {
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
    let layersInGroup: LayerDataList // child layers for THIS group
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    
    let position: CGPoint
    let size: LayerSize

    // Assumes parentSize has already been scaled, etc.
    let parentSize: CGSize
    let parentDisablesPosition: Bool

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
        adjustPosition(
            //size: layerViewModel.readSize, // size.asCGSize(parentSize),
            size: size.asCGSizeForLayer(parentSize: parentSize,
                                        readSize: layerViewModel.readSize),
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
                frameAlignment: anchoring.toAlignment))

            .background {
                // TODO: Better way to handle slight gap between outside stroke and background edge when using corner radius? Outside stroke is actually an .overlay'd shape that is slightly larger than the stroked shape.
//                backgroundColor.cornerRadius(cornerRadius - (stroke.stroke == .outside ? stroke.width/2 : 0))
                backgroundColor.cornerRadius(strokeAdjustedCornerRadius)
            }
        
        //            // DEBUG ONLY
        //        #if DEV_DEBUG
        //            .border(.red)
        //        #endif
        
            .modifier(PreviewSidebarHighlightModifier(
                viewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                nodeId: interactiveLayer.id.layerNodeId,
                highlightedSidebarLayers: document.graphUI.highlightedSidebarLayers,
                scale: scale))
                
            .modifier(PreviewLayerRotationModifier(
                graph: graph,
                viewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                rotationX: rotationX,
                rotationY: rotationY,
                rotationZ: rotationZ))
        
        // .clipped modifier should come before the offset/position modifier,
        // so that it's affected by the offset/position modifier
            .modifier(ClippedModifier(isClipped: isClipped,
                                      cornerRadius: strokeAdjustedCornerRadius))
        
        // Stroke needs to come AFTER the .clipped modifier, so that .outsideStroke is not cut off.
            .modifier(ApplyStroke(viewModel: layerViewModel,
                                  isPinnedViewRendering: isPinnedViewRendering,
                                  stroke: stroke,
                                  // Uses non-stroke adjusted corner radius, since .stitchStroke will handle the adjustment 
                                  cornerRadius: cornerRadius))

            .opacity(opacity) // opacity on group and all its contents
        
            .scaleEffect(CGFloat(scale),
                         anchor: pivot.toPivot)
                
            .modifier(PreviewCommonPositionModifier(
                graph: graph,
                viewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                parentDisablesPosition: parentDisablesPosition, 
                parentSize: parentSize,
                pos: pos))
        
        // SwiftUI gestures must be applied after .position modifier
            .modifier(PreviewWindowElementSwiftUIGestures(
                document: document,
                graph: graph,
                interactiveLayer: interactiveLayer,
                position: position,
                pos: pos,
                size: _size,
                parentSize: parentSize,
                minimumDragDistance: DEFAULT_MINIMUM_DRAG_DISTANCE))
    }

    @ViewBuilder
    private var groupLayer: some View {
        PreviewLayersView(document: document,
                          graph: graph,
                          layers: layersInGroup,
//                          isPinnedViewRendering: isPinnedViewRendering,
                          // This Group's size will be the `parentSize` for the `layersInGroup`
                          parentSize: _size,
                          parentId: interactiveLayer.id.layerNodeId,
                          parentOrientation: orientation,
                          parentSpacing: spacing,
                          parentCornerRadius: cornerRadius,
                          // i.e. if this view (a LayerGroup) uses .hug, then its children will not use their own .position values.
                          parentUsesHug: usesHug,
                          noFixedSizeForLayerGroup: noFixedSizeForLayerGroup,
                          parentGridData: gridData,
                          isGhostView: !isPinnedViewRendering)
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

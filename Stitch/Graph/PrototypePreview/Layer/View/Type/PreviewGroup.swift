//
//  PreviewGroup.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/4/21.
//

import SwiftUI
import StitchSchemaKit

extension LayerViewModel {
    var getGridData: PreviewGridData? {
        guard self.layer == .group else {
            return nil
        }
        
        return .init(
            horizontalSpacingBetweenColumns: self.spacingBetweenGridColumns.getNumber ?? .zero,
            verticalSpacingBetweenRows: self.spacingBetweenGridRows.getNumber ?? .zero,
            alignmentOfItemWithinGridCell: (self.itemAlignmentWithinGridCell.getAnchoring ?? .centerCenter).toAlignment
        )
    }
}

struct PreviewGroupLayer: View {
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let layersInGroup: LayerDataList // child layers for THIS group
    
    let interactiveLayer: InteractiveLayer
    
    let position: CGSize
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
    let padding: CGFloat
    
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
    
    var useParentSizeForAnchoring: Bool {
        usesHug && !parentDisablesPosition
    }
    
    var pos: StitchPosition {
        adjustPosition(
            size: layerViewModel.readSize, // size.asCGSize(parentSize),
            position: position,
            anchor: anchoring,
            parentSize: parentSize)
    }
    
    var body: some View {

        groupLayer
        
        // TODO: add "child alignment" input on Group Layer node? or find some other solution for how a group with an orientation can position children that have static sizes
        // TODO: don't need this if we're using the "hug" case in `LayerGroupPositionModifier` ?
            .modifier(PreviewCommonSizeModifier(
                viewModel: layerViewModel,
                size: size,
                parentSize: parentSize,
                frameAlignment: anchoring.toAlignment,
                useParentSizeForAnchoring: useParentSizeForAnchoring))
                
            .background(backgroundColor)
        
        //            // DEBUG ONLY
        //        #if DEV_DEBUG
        //            .border(.red)
        //        #endif
        
            .modifier(PreviewSidebarHighlightModifier(
                nodeId: interactiveLayer.id.layerNodeId,
                highlightedSidebarLayers: graph.graphUI.highlightedSidebbarLayers,
                scale: scale))
                
            .modifier(PreviewLayerRotationModifier(
                rotationX: rotationX,
                rotationY: rotationY,
                rotationZ: rotationZ))
        
        // .clipped modifier should come before the offset/position modifier,
        // so that it's affected by the offset/position modifier
            .modifier(ClippedModifier(isClipped: isClipped,
                                     cornerRadius: cornerRadius))

            .opacity(opacity) // opacity on group and all its contents
        
            .scaleEffect(CGFloat(scale),
                         anchor: pivot.toPivot)
                
            .modifier(PreviewCommonPositionModifier(
                parentDisablesPosition: parentDisablesPosition,
                pos: pos))
        
        // SwiftUI gestures must be applied after .position modifier
            .modifier(PreviewWindowElementSwiftUIGestures(
                graph: graph,
                interactiveLayer: interactiveLayer,
                position: position.toCGPoint,
                pos: pos,
                size: _size,
                parentSize: parentSize,
                minimumDragDistance: DEFAULT_MINIMUM_DRAG_DISTANCE))
    }

    @ViewBuilder
    private var groupLayer: some View {
        PreviewLayersView(graph: graph,
                          layers: layersInGroup,
                          // This Group's size will be the `parentSize` for the `layersInGroup`
                          parentSize: _size,
                          parentId: interactiveLayer.id.layerNodeId,
                          parentOrientation: orientation,
                          parentOrientationPadding: padding,
                          parentCornerRadius: cornerRadius,
                          // i.e. if this view (a LayerGroup) uses .hug, then its children will not use their own .position values.
                          parentUsesHug: usesHug,
                          parentGridData: gridData)
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

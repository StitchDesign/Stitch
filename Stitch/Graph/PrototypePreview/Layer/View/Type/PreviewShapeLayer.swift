//
//  PreviewShape.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/21.
//

import SwiftUI
import StitchSchemaKit

// `InsettableShape` protocol means we can use .strokeBorder modifier;
// available for SwiftUI Shapes like Ellipse and RoundedRectangle,
// but not currently implemented for CGPoints/Path-based custom shapes like our Triangle;
/// `struct PreviewShapeLayer<T: View & InsettableShape>: View, CommonView {`
///
struct PreviewShapeLayer: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    
    let color: Color
    let position: StitchPosition
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
    let stroke: LayerStrokeData
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    let pivot: Anchoring
    
    let shadowColor: Color
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: StitchPosition

    let previewShapeKind: PreviewShapeLayerKind
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool
    
    let usesAbsoluteCoordinates: Bool
    
    var layerNodeSize: CGSize {
        size.asCGSize(parentSize)
    }
    
    
    var body: some View {
        
        let parentSize = CGSize(width: 200, height: 200)
        let childSize = CGSize(width: 100, height: 100)
        
        let childPos = adjustPosition(
            size: childSize,
            position: .zero,
            anchor: .topLeft,
            parentSize: parentSize)
        
        Ellipse().fill(.green)
            .frame(width: childSize.width, height: childSize.height)
            .offset(x: childPos.x, y: childPos.y)
        
    }
    
    @ViewBuilder
    func builtShape(layerNodeSize: CGSize) -> some View {
        StitchShape(
            stroke: stroke,
            color: color,
            opacity: opacity,
            layerNodeSize: layerNodeSize,
            previewShapeKind: previewShapeKind,
            usesAbsoluteCoordinates: usesAbsoluteCoordinates)
    }
}

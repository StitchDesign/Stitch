//
//  PreviewCommon.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/14/21.
//

import SwiftUI
import StitchSchemaKit

// Note: used by many but not all layers; e.g. Group Layer does not use this
struct PreviewCommonModifier: ViewModifier {

    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let interactiveLayer: InteractiveLayer
    let position: CGSize
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    
    let aspectRatio: AspectRatioData? = nil
    let constraint: LengthDimension? = nil
    
    // should receive LayerSize, so can use `nil` for a .frame dimension when we have LayerDimension.fill/grow
    let size: LayerSize
    
    // TODO: can be `nil` if we're using min/max width etc.
//    var width: LayerDimension {
//        size.width
//    }
    
//    let minWidth: NumericalLayerDimension? = nil
//    let maxWidth: NumericalLayerDimension? = nil
    
    var minWidth: NumericalLayerDimension? {
        .number(layerViewModel.minSize.getSize!.asAlgebraicCGSize.width)
    }
    
    var maxWidth: NumericalLayerDimension? {
        .number(layerViewModel.maxSize.getSize!.asAlgebraicCGSize.width)
    }

//    var height: LayerDimension {
//        size.height
//    }
    
//    let minHeight: NumericalLayerDimension? = nil
//    let maxHeight: NumericalLayerDimension? = nil
    
    var minHeight: NumericalLayerDimension? {
//        layerViewModel.minSize.height
        .number(layerViewModel.minSize.getSize!.asAlgebraicCGSize.height)
    }
    
    var maxHeight: NumericalLayerDimension? {
//        layerViewModel.maxSize.height
        .number(layerViewModel.maxSize.getSize!.asAlgebraicCGSize.height)
    }
        
    let scale: Double
    let anchoring: Anchoring
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
    
    var isForShapeLayer: Bool = false
    
    // Assumes parentSize has already been scaled etc.
    let parentSize: CGSize
    let parentDisablesPosition: Bool

    // Only Text layers have their own alignment,
    // based on text alignment and vertical alignment.
    // Other views default to .center
    var frameAlignment: Alignment = .center

    var clipForMapLayerProjetThumbnailCreation: Bool = false
    
    func body(content: Content) -> some View {

        content
            .modifier(PreviewCommonSizeModifier(
                    viewModel: layerViewModel,
                    aspectRatio: aspectRatio,
                    constraint: constraint,
                    size: size,
                    minWidth: minWidth,
                    maxWidth: maxWidth,
                    minHeight: minHeight,
                    maxHeight: maxHeight,
                    parentSize: parentSize,
                    sizingScenario: layerViewModel.sizingScenario.getSizingScenario ?? .defaultSizingScenario,
                    frameAlignment: frameAlignment))
        
            // Only for MapLayer, specifically for thumbnail-creation edge case
            .modifier(ClippedModifier(
                isClipped: clipForMapLayerProjetThumbnailCreation,
                // no clipping for map
                cornerRadius: .zero))

            .modifier(PreviewCommonModifierWithoutFrame(
                graph: graph,
                layerViewModel: layerViewModel,
                interactiveLayer: interactiveLayer,
                position: position,
                rotationX: rotationX,
                rotationY: rotationY,
                rotationZ: rotationZ,
                // actual calculated size at which we're displaying the image
                size: size,
                minimumDragDistance: DEFAULT_MINIMUM_DRAG_DISTANCE,
                scale: scale,
                anchoring: anchoring,
                blurRadius: blurRadius,
                blendMode: blendMode,
                brightness: brightness,
                colorInvert: colorInvert,
                contrast: contrast,
                hueRotation: hueRotation,
                saturation: saturation,
                pivot: pivot,
                shadowColor: shadowColor,
                shadowOpacity: shadowOpacity,
                shadowRadius: shadowRadius,
                shadowOffset: shadowOffset,
                isForShapeLayer: isForShapeLayer,
                parentSize: parentSize,
                parentDisablesPosition: parentDisablesPosition))
    }
}

struct PreviewCommonView_REPL: View {

    let windowSize = CGSize(width: 390, height: 844)

    var scale: CGFloat = 0.4

    //    var anchoring: Anchoring = .topLeft
    //    var anchoring: Anchoring = .center
    //    var anchoring: Anchoring = .topRight
    var anchoring: Anchoring = .bottomCenter

    var size: CGSize {
        CGSize(width: 800, height: 800)
    }

    var scaledSize: CGSize {
        size.scaleBy(scale)
    }

    //    var position: StitchPosition = .zero
    //    var position: StitchPosition = .init(width: 0, height: 422)
    var position: StitchPosition = .init(width: 0, height: -422)

    // 422 * 0.4
    var scaledPosition: StitchPosition {
        position.scaleBy(scale)
    }

    var pos: StitchPosition {
        adjustPosition(
            size: scaledSize,
            position: position,
            anchor: anchoring,
            parentSize: windowSize)
    }

    var body: some View {
        ZStack { // mock preview window
            Color.white.zIndex(-1) // mock background

            Rectangle().fill(.blue.opacity(0.5))
                .frame(width: size.width,
                       height: size.height,
                       // ALWAYS CENTER, regardless of anchoring;
                       alignment: .center)
                .scaleEffect(CGFloat(scale))
                .position(x: pos.width, y: pos.height)

        }
        .frame(windowSize)
        .border(.red, width: 4)
    }
}

struct PreviewCommonView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewCommonView_REPL()
    }
}

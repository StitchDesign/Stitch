//
//  LayerEvalHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/9/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension Double {
    static let defaultWidthAxisRatio = 1.0
    static let defaultHeightAxisRatio = 1.0
}

// TODO: tech debt: do this for shadow-data, rotation-data, layer-effect-data
extension LayerViewModel {
    
    var getMinWidth: LayerDimension? {
        self.minSize.getSize?.width
    }
    
    var getMaxWidth: LayerDimension? {
        self.maxSize.getSize?.width
    }
    
    var getMinHeight: LayerDimension? {
        self.minSize.getSize?.height
    }
    
    var getMaxHeight: LayerDimension? {
        self.maxSize.getSize?.height
    }
    
    var getSizingScenario: SizingScenario {
        self.sizingScenario.getSizingScenario ?? .defaultSizingScenario
    }
    
    func getAspectRatioData() -> AspectRatioData {
        .init(widthAxis: self.widthAxis.getNumber ?? .defaultWidthAxisRatio,
              heightAxis: self.heightAxis.getNumber ?? .defaultHeightAxisRatio,
              contentMode: (self.contentMode.getContentMode ?? .defaultContentMode).toSwiftUIContent)
    }
    
    func getLayerStrokeData() -> LayerStrokeData {
        .init(stroke: self.strokePosition.getLayerStroke ?? .defaultStroke,
              color: self.strokeColor.getColor ?? .black,
              width: self.strokeWidth.getNumber ?? .zero,
              strokeStart: self.strokeStart.getNumber ?? .zero,
              strokeEnd: self.strokeEnd.getNumber ?? 1.0,
              strokeLineCap: self.strokeLineCap.getStrokeLineCap ?? .defaultStrokeLineCap,
              strokeLineJoin: self.strokeLineJoin.getStrokeLineJoin ?? .defaultStrokeLineJoin)
    }
}

// Note: used by Oval Layer Node, Rectangle Layer Node and Shape Layer Node;
// the first two have the same indices (order of inputs),
// the third does not.
struct ShapeLayerView: View {

    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerViewModel
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool

    var body: some View {
        let stroke = viewModel.getLayerStrokeData()

        let coordinateSystem = viewModel.coordinateSystem.getShapeCoordinates ?? .relative

        PreviewShapeLayer(
            graph: graph,
            layerViewModel: viewModel,
            interactiveLayer: viewModel.interactiveLayer,
            color: viewModel.color.getColor ?? falseColor,
            position: viewModel.position.getPosition ?? .zero,
            rotationX: viewModel.rotationX.getNumber ?? .zero,
            rotationY: viewModel.rotationY.getNumber ?? .zero,
            rotationZ: viewModel.rotationZ.getNumber ?? .zero,
            size: viewModel.size.getSize ?? .zero,
            opacity: viewModel.opacity.getNumber ?? defaultOpacityNumber,
            scale: viewModel.scale.getNumber ?? defaultScaleNumber,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            stroke: stroke,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            pivot: viewModel.pivot.getAnchoring ?? .defaultPivot,
            shadowColor: viewModel.shadowColor.getColor ?? .defaultShadowColor,
            shadowOpacity: viewModel.shadowOpacity.getNumber ?? .defaultShadowOpacity,
            shadowRadius: viewModel.shadowRadius.getNumber ?? .defaultShadowOpacity,
            shadowOffset: viewModel.shadowOffset.getPosition ?? .defaultShadowOffset,
            // better?: just pass in the cornerRadius to PreviewShapeLayer,
            // and provide cornerRadius to `buildStitchShape`.
            previewShapeKind: self.getPreviewShapeKind(cornerRadius: viewModel.cornerRadius.getNumber ?? .zero,
                                                       shape: viewModel.shape.getShape),
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            usesAbsoluteCoordinates: coordinateSystem == .absolute)
    }

    func getPreviewShapeKind(cornerRadius: CGFloat,
                             shape: CustomShape?) -> PreviewShapeLayerKind {
        // When passing a Shape Layer node's size to Shape Maker (needed for path-based shapes),
        // we need to scale it according to the parentSize.

        switch viewModel.layer {
        case .oval:
            return .swiftUIOval
        case .rectangle:
            return .swiftUIRectangle(cornerRadius)
        default:
            if let customShape = shape {
                //        log("shapeLayerEvalHelper: Had path-based shape")
                return .pathBased(customShape)
            } else {
                //        log("shapeLayerEvalHelper: None")
                return .none
            }
        }
    }
}

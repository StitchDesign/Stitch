//
//  ShapeLayerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/8/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension LayerInputPortSet {
    
    @MainActor
    static let strokeInputs: LayerInputPortSet = [
        .strokePosition,
        .strokeWidth,
        .strokeColor,
        .strokeStart,
        .strokeEnd,
        .strokeLineCap,
        .strokeLineJoin
    ]
    
    @MainActor
    static let layerEffects: LayerInputPortSet = [
        .blurRadius,
        .blendMode,
        .brightness,
        .colorInvert,
        .contrast,
        .hueRotation,
        .saturation
    ]
    
    @MainActor
    static let typography: LayerInputPortSet = [
        .fontSize,
        .textAlignment,
        .verticalAlignment,
        .textDecoration,
        .textFont,
    ]
    
    @MainActor
    static let aspectRatio: LayerInputPortSet = [
        .widthAxis,
        .heightAxis,
        .contentMode
    ]
    
    @MainActor
    static let sizing: LayerInputPortSet = [
        .minSize,
        .maxSize,
        .sizingScenario
    ]
    
    // LayerGroup only?
    @MainActor
    static let paddingAndSpacing: LayerInputPortSet = [
//        .padding,
        .spacing
    ]
    
    @MainActor
    static let pinning: LayerInputPortSet = [
        .isPinned,
        .pinTo,
        .pinAnchor,
        .pinOffset
    ]
    
    @MainActor
    static let layerPaddingAndMargin: LayerInputPortSet = [
        .layerPadding,
        .layerMargin
    ]
    
    @MainActor
    static let offsetInGroup: LayerInputPortSet = [
        .offsetInGroup // belongs with "positioning" section
    ]
}

extension StrokeLineCap: PortValueEnum {
    static let defaultStrokeLineCap: Self = .round
    
    static var portValueTypeGetter: PortValueTypeGetter<StrokeLineCap> {
        PortValue.strokeLineCap
    }
    
    var toCGLineCap: CGLineCap {
        switch self {
        case .butt:
            return .butt
        case .square:
            return .square
        case .round:
            return .round
        }
    }
}


extension PortValue {
    // Takes any PortValue, and returns a MobileHapticStyle
    func coerceToStrokeLineCap() -> StrokeLineCap {
        switch self {
        case .strokeLineCap(let x):
            return x
        case .number(let x):
            return StrokeLineCap.fromNumber(x).getStrokeLineCap ?? .defaultStrokeLineCap
        default:
            return .defaultStrokeLineCap
        }
    }
}

func strokeLineCapCoercer(_ values: PortValues) -> PortValues {
    values
        .map { $0.coerceToStrokeLineCap() }
        .map(PortValue.strokeLineCap)
}

extension StrokeLineJoin: PortValueEnum {
    static let defaultStrokeLineJoin: Self = .round
    
    static var portValueTypeGetter: PortValueTypeGetter<StrokeLineJoin> {
        PortValue.strokeLineJoin
    }
    
    var toCGLineJoin: CGLineJoin {
        switch self {
        case .bevel:
            return .bevel
        case .miter:
            return .miter
        case .round:
            return .round
        }
    }
}

extension PortValue {
    // Takes any PortValue, and returns a MobileHapticStyle
    func coerceToStrokeLineJoin() -> StrokeLineJoin {
        switch self {
        case .strokeLineJoin(let x):
            return x
        case .number(let x):
            return StrokeLineJoin.fromNumber(x).getStrokeLineJoin ?? .defaultStrokeLineJoin
        default:
            return .defaultStrokeLineJoin
        }
    }
}

func strokeLineJoinCoercer(_ values: PortValues) -> PortValues {
    values
        .map { $0.coerceToStrokeLineJoin() }
        .map(PortValue.strokeLineJoin)
}

extension ShapeCoordinates: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<ShapeCoordinates> {
        PortValue.shapeCoordinates
    }
}

struct ShapeLayerNode: LayerNodeDefinition {
    static let layer = Layer.shape

    static let inputDefinitions: LayerInputPortSet = .init([
        .shape,
        .color,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .coordinateSystem,
        .pivot,
        .masks,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing)
        .union(.pinning)
        .union(.layerPaddingAndMargin)
        .union(.offsetInGroup)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: Binding<LayerRealityCameraContent?>) -> some View {
        ShapeLayerView(document: document,
                       graph: graph,
                       viewModel: viewModel,
                       isPinnedViewRendering: isPinnedViewRendering,
                       parentSize: parentSize,
                       parentDisablesPosition: parentDisablesPosition,
                       parentIsScrollableGrid: parentIsScrollableGrid)
    }
}

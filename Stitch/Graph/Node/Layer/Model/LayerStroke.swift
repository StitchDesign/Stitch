//
//  LayerStroke.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/15/22.
//

import SwiftUI
import StitchSchemaKit

extension LayerStroke: PortValueEnum {

    static var defaultStroke: LayerStroke {
        .none
    }

    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.layerStroke
    }

    var display: String {
        switch self {
        case .none:
            return "None"
        case .inside:
            return "Inside"
        case .outside:
            return "Outside"
        }
    }
}

struct LayerStrokeData: Equatable {
    var stroke: LayerStroke
    var color: Color
    var width: CGFloat
    var strokeStart: CGFloat
    var strokeEnd: CGFloat
    var strokeLineCap: StrokeLineCap
    var strokeLineJoin: StrokeLineJoin
}

extension LayerStrokeData {
    static let defaultEmptyStroke: LayerStrokeData = .init(
        stroke: .none,
        color: .black,
        width: 0,
        strokeStart: .zero,
        strokeEnd: 1.0,
        strokeLineCap: .defaultStrokeLineCap,
        strokeLineJoin: .defaultStrokeLineJoin)
    
    static let defaultStroke: LayerStrokeData = .init(
        stroke: .outside,
        color: .black,
        width: 4,
        strokeStart: .zero,
        strokeEnd: 1.0,
        strokeLineCap: .defaultStrokeLineCap,
        strokeLineJoin: .defaultStrokeLineJoin)
}

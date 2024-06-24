//
//  LayerDimensionField.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

enum LayerDimensionField: Equatable {
    case auto,
         fill,
         hug,
         number(Double),
         percent(Double)
}

extension LayerDimensionField {
    var stringValue: String {
        switch self {
        case .auto:
            return .AUTO_SIZE_STRING
        case .fill:
            return .FILL_SIZE_STRING
        case .hug:
            return .HUG_SIZE_STRING
        case .number(let double):
            return GlobalFormatter.string(for: double) ?? double.description
        case .percent(let double):
            return "\(double.description)%"
        }
    }

    var numberValue: Double? {
        switch self {
        case .number(let double), .percent(let double):
            return double
        default:
            return nil
        }
    }

    var layerDimension: LayerDimension {
        switch self {
        case .auto:
            return .auto
        case .fill:
            return .fill
        case .hug:
            return .hug
        case .number(let double):
            return .number(double)
        case .percent(let double):
            return .parentPercent(double)
        }
    }
}

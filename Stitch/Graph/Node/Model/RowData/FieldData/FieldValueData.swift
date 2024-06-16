//
//  FieldValue.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/27/23.
//

import Foundation
import StitchSchemaKit

enum FieldValueNumberType: Equatable {
    case number, layerDimension(LayerDimensionNumberType)
}

enum LayerDimensionNumberType {
    case number, auto, fill, hug, percent
}

extension FieldValueNumberType {
    func createFieldValueForAdjustmentBar(from double: Double) -> FieldValue {
        switch self {
        case .number:
            return .number(double)
        case .layerDimension(let layerDimensionNumberType):
            switch layerDimensionNumberType {
                // Allow number to replace the `auto`, `fill` etc. setting
            case .number, .auto, .fill, .hug:
                return .layerDimension(.number(double))
            case .percent:
                return .layerDimension(.percent(double))
            }
        }
    }

    var isLayerDimension: Bool {
        switch self {
        case .number:
            return false
        case .layerDimension:
            return true
        }
    }

    var isPercentage: Bool {
        switch self {
        case .number:
            return false
        case .layerDimension(let layerDimension):
            switch layerDimension {
            case .percent:
                return true
            default:
                return false
            }
        }
    }
}

extension LayerDimensionField {
    var fieldValueNumberType: FieldValueNumberType {
        switch self {
        case .auto:
            return .layerDimension(.auto)
        case .fill:
            return .layerDimension(.fill)
        case .hug:
            return .layerDimension(.hug)
        case .number:
            return .layerDimension(.number)
        case .percent:
            return .layerDimension(.percent)
        }
    }
}

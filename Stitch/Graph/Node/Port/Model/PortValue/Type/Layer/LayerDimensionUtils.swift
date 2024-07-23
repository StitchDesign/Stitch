//
//  LayerDimension.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit




extension String {
    static let AUTO_SIZE_STRING = "auto"
    static let FILL_SIZE_STRING = "fill"
    static let HUG_SIZE_STRING = "hug"
}

// percent:
// 1 = 100%
// 0.5 = 50%
// 0.3326 = 33.26%
// 0 = 0%

// or better?:
// "1%" -> 0.01
// "10%" -> 0.1
// "33%" -> 0.33
// "100%" -> 1.0
// "200%" -> 2.0

// struct Percentage: Codable, Equatable, Codable {
//
// }

// keep as eg 200, 100, etc.
// only do the
func parsePercentage(_ edit: String) -> Double? {
    if let last = edit.last, last == "%" {
        return toNumber(String(edit.dropLast()))
    }
    return nil
}

extension Double {
    var asPercentage: String {
        "\(self)%"
    }
}

extension LayerDimension: CustomStringConvertible {
    // MARK: string coercison causes perf loss (GitHub issue #3120)
    public var description: String {
        switch self {
        case .auto:
            return .AUTO_SIZE_STRING
        case .parentPercent(let x):
            //            return "\(x.coerceToUserFriendlyString)%"
            return "\(x.description)%"
        case .number(let x):
            //            return x.coerceToUserFriendlyString
            return x.description
        case .fill:
            return .FILL_SIZE_STRING
        case .hug:
            return .HUG_SIZE_STRING
        }
    }
}

extension String {
    var asLayerDimension: LayerDimension? {
        .fromUserEdit(edit: self)
    }
}

extension LayerDimension {
    
    // LayerDimension's dropdown choices excludes the numerical case
    static let choices: [String] = [
        LayerDimension.auto.description,
        LayerDimension.fill.description,
        LayerDimension.hug.description
    ].map(\.description)
    
    init(_ num: CGFloat) {
        self = .number(num)
    }

    static func fromUserEdit(edit: String) -> LayerDimension? {
        if edit == .AUTO_SIZE_STRING {
            return .auto
        } else if edit == .FILL_SIZE_STRING {
            return .fill
        } else if edit == .HUG_SIZE_STRING {
            return .hug
        } else if let n = parsePercentage(edit) {
            return .parentPercent(n)
        } else if let n = toNumber(edit) {
            return .number(CGFloat(n))
        } else {
            return nil
        }
    }

    func asCGFloat(_ parentLength: CGFloat) -> CGFloat {
        switch self {
        case .number(let cGFloat):
            return cGFloat
        case .auto:
            return parentLength
        case .parentPercent(let double):
            return parentLength * zeroCompatibleDivision(numerator: double,
                                                         denominator: 100)
        case .fill, .hug:
            // TODO: LayerDimension.fill
            return parentLength
        }
    }

    func asCGFloat(parentLength: CGFloat,
                   resourceLength: CGFloat) -> CGFloat {
        switch self {
        case .number(let cGFloat):
            return cGFloat
        case .auto:
            return resourceLength
        case .parentPercent(let double):
            return parentLength * zeroCompatibleDivision(numerator: double, denominator: 100)
        case .fill, .hug:
            // TODO: LayerDimension.fill
            return parentLength
        }
    }

    // Useful eg when converting from .size -> .position,
    // or .layerDimension -> .number
    var asNumber: Double {
        switch self {
        case .number(let cGFloat):
            return cGFloat
        case .auto:
            return 0
        case .parentPercent(let x):
            return zeroCompatibleDivision(numerator: x,
                                          denominator: 100)
        case .fill, .hug:
            // TODO: LayerDimension.fill
            return 0
        }
    }
    
    var isFill: Bool {
        self == .fill
    }
    
    // Adjustment bar expects parent-percentage of e.g. "50%" to be 50, not 0.5
    var asAdjustmentbarNumber: Double {
        switch self {
        case .number(let x):
            return x
        case .parentPercent(let x):
            return x
        case .auto:
            return 0.0
        case .fill, .hug:
            // TODO: LayerDimension.fill
            return 0.0
        }
    }

    var isAuto: Bool {
        switch self {
        case .auto:
            return true
        default:
            return false
        }
    }
    
    var isHug: Bool {
        self == .hug
    }
    
    var isParentPercentage: Bool {
        switch self {
        case .parentPercent:
            return true
        default:
            return false
        }
    }

    var isNumber: Bool {
        switch self {
        case .number:
            return true
        default:
            return false
        }
    }
    
    var getNumber: CGFloat? {
        switch self {
        case .number(let x):
            return x
        default:
            return nil
        }
    }

    var asBool: Bool {
        getNumber.map { $0 != .zero } ?? false
    }

    var fieldValue: LayerDimensionField {
        switch self {
        case .number(let cGFloat):
            return .number(cGFloat)
        case .auto:
            return .auto
        case .parentPercent(let double):
            return .percent(double)
        case .fill:
            // TODO: LayerDimension.fill
            return .fill
        case .hug:
            return .hug
        }
    }
}

//
//  LayerDimension.swift
//  Stitch
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

enum NonNumberLayerDimension: String, Equatable, Codable, CaseIterable {
    case auto, fill, hug
}

extension GraphState {
    @MainActor
    func getFilteredLayerDimensionChoices(nodeId: NodeId,
                                          nodeKind: NodeKind,
                                          layerInputObserver: LayerInputObserver?) -> [NonNumberLayerDimension] {
        
        let allChoices = LayerDimension.choicesAsNonNumberLayerDimension
        
        // If we have a patch or group node input, show all layer-dimension choices
        guard let layer = nodeKind.getLayer else {
            // TODO: how to handle patch and group nodes' layer-dimension fields?
            return allChoices
        }
        
        // TODO: `layerInputObserver` is not passed down to layer inputs on the canvas?
        if let layerInputObserver = layerInputObserver,
            layerInputObserver.port == .minSize || layerInputObserver.port == .maxSize {
            // Min and max size can only use `auto` (i.e. none), `static number` or `parent percentage`
            return [.auto]
        }
                
        // Note: `filter` so that choice order stays the same
        return allChoices.filter { dimension in
            switch dimension {
            case  .fill:
                // All layers support `fill`
                return true
            case .auto:
                return layer.canUseAutoLayerDimension
            case .hug:
                // Show `hug` just if this is a layer group AND the layer group has orientation != ZStack
                let isLayerGroup = layer == .group
                let canUseHug = self.getLayerNode(id: nodeId)?.layerNode?.orientationPort.activeValue.getOrientation?.canUseHug ?? false
                return isLayerGroup && canUseHug
            }
        }
    }
}

extension LayerDimension {
    
    // LayerDimension's dropdown choices excludes the numerical case
    static let choicesAsNonNumberLayerDimension: [NonNumberLayerDimension] = NonNumberLayerDimension.allCases
    
    static let choices: [String] = Self.choicesAsNonNumberLayerDimension.map(\.rawValue)
    
    init(_ num: CGFloat) {
        self = .number(num)
    }

    // TODO: restrict edits to the logic described in `getFilteredChoices` in `InputValueView`
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
    
    func asCGFloatIfNumber(_ parentLength: CGFloat) -> CGFloat? {
        switch self {
        case .number(let cGFloat):
            return cGFloat
        case .parentPercent(let double):
            return parentLength * zeroCompatibleDivision(numerator: double,
                                                         denominator: 100)
        case .fill:
            // Fill is always simply parent's size
            return parentLength
            
        // .auto and .hug mean "Do not apply .frame", and so we must use the layer's .readSize instead
        case .auto, .hug:
            return nil
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
    // TODO: in which contexts is this used? ... we don't always know the parent's size, or the parent's size may not apply (e.g. turning a LayerDimension into a Point3D)
    var asNumber: Double {
        switch self {
        case .number(let cGFloat):
            return cGFloat
        
        // TODO: need actual parent size?
        case .parentPercent(let x):
            return zeroCompatibleDivision(numerator: x,
                                          denominator: 100)
        
        // TODO: .fill should actually be "100% of parent"
        case .auto, .fill, .hug:
            // TODO: LayerDimension.fill should be 100% of parent
            return 0
        }
    }
    
    // `hug` and `auto` have no fixed size when applied to a LayerGroup i.e. ZStack or HStack
    var noFixedSizeForLayerGroup: Bool {
        switch self {
        case .hug, .auto:
            return true
        case .fill, .number, .parentPercent:
            return false
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

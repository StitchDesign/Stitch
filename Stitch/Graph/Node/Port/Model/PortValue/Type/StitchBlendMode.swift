//
//  StitchBlendMode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/5/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension StitchBlendMode: PortValueEnum {

    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.blendMode
    }

    static let defaultBlendMode: Self = .normal

    var display: String {
        self.rawValue
    }

    var toBlendMode: BlendMode {
        switch self {

        case .normal:
            return .normal
        case .darken:
            return .darken
        case .multiply:
            return .multiply
        case .colorBurn:
            return .colorBurn
        case .plusDarker:
            return .plusDarker
        case .lighten:
            return .lighten
        case .screen:
            return .screen
        case .colorDodge:
            return .colorDodge
        case .plusLighter:
            return .plusLighter
        case .overlay:
            return .overlay
        case .softLight:
            return .softLight
        case .hardLight:
            return .hardLight
        case .difference:
            return .difference
        case .exclusion:
            return .exclusion
        case .hue:
            return .hue
        case .saturation:
            return .saturation
        case .color:
            return .color
        case .luminosity:
            return .luminosity
        case .sourceAtop:
            return .sourceAtop
        case .destinationOver:
            return .destinationOver
        case .destinationOut:
            return .destinationOut
        }
    }
}

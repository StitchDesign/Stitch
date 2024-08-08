//
//  UnpackedValueCoercer.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/7/24.
//

import Foundation
import StitchSchemaKit

// MARK: - need to move existing logic from Coercers.swift file

extension PortValue {
    func unpackedPositionCoercer() -> PortValue {
        switch self {
        case .position:
            return self
        case .number(let x):
            return .position(x.toStitchPosition)
        case .size(let x):
            return .position(x.asAlgebraicCGSize)
        case .layerDimension(let x):
            return .position(StitchPosition(
                                width: x.asNumber,
                                height: x.asNumber))
        case .int(let x):
            return .position(x.toStitchPosition)
        case .point3D(let x):
            return .position(x.toStitchPosition)
        case .point4D(let x):
            return .position(x.toStitchPosition)
        case .json(let x):
            return x.value.toStitchPosition.map(PortValue.position) ?? defaultPositionFalse
        case .bool(let x):
            return .position(x ? .multiplicationIdentity : .zero)
        default:
            return coerceToTruthyOrFalsey(self,
                                          graphTime: .zero) // only needed for pulse
                ? defaultPositionTrue
                : defaultPositionFalse
        }
    }
}

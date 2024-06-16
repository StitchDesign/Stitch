//
//  AdjustmentBarStepScale.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

enum AdjustmentBarStepScale: String, CaseIterable, Equatable, Codable, Hashable {
    case small, normal, large

    var stepScaleSize: CGFloat {
        switch self {
        case .small:
            return 0.1
        case .normal:
            return 1
        case .large:
            return 10
        }
    }

    var display: String {
        self.rawValue.capitalized
    }
}

extension AdjustmentBarStepScale {
    init(_ n: Double) {
        // Always start on `normal` step-scale,
        // regardless of what the number is.
        self = .normal
    }
}

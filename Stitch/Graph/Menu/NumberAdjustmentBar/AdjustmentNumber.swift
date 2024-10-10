//
//  Adjustment.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/17/22.
//

import Foundation
import StitchSchemaKit

struct AdjustmentNumber: Codable, Identifiable, Equatable, Hashable {
    let number: Double

    var id: Double {
        number
    }

    init(_ number: Double) {
        self.number = number
    }
}

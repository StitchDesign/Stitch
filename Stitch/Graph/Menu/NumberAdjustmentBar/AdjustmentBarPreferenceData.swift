//
//  AdjustmentBarPreferenceData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/8/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Preference data for individual adjustment bar items

typealias BarPrefDict = [AdjustmentNumber: BarPrefData]

struct BarPrefData {
    let number: Double
    let center: Anchor<CGPoint>
    let field: FieldCoordinate
}

struct BarPrefKey: PreferenceKey {
    typealias Value = BarPrefDict

    static let defaultValue: BarPrefDict = [:]

    static func reduce(value: inout BarPrefDict, nextValue: () -> BarPrefDict) {
        // append(contentsOf) is like a flat concat
        // value.append(contentsOf: nextValue())
        let newValue = nextValue()
        return value.merge(newValue) { (p: BarPrefData, _: BarPrefData) -> BarPrefData in
            p
        }
    }
}

// Preference data for adjustment bar's center

let SCROLL_CENTER_KEY: Int = 1

typealias ScrollCenterPrefDict = [Int: ScrollCenterPrefData]

struct ScrollCenterPrefData: Identifiable {
    let id = UUID()
    let center: Anchor<CGPoint>
}

struct ScrollCenterPrefKey: PreferenceKey {
    typealias Value = ScrollCenterPrefDict

    static let defaultValue: ScrollCenterPrefDict = [:]

    static func reduce(value: inout ScrollCenterPrefDict, nextValue: () -> ScrollCenterPrefDict) {
        let newValue = nextValue()
        return value.merge(newValue) { (p: ScrollCenterPrefData, _: ScrollCenterPrefData) -> ScrollCenterPrefData in
            p
        }
    }
}

//
//  EdgeStyle.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/9/24.
//

import Foundation
import StitchSchemaKit

enum EdgeStyle: String, CaseIterable {
    case circuit = "Circuit",
         curve = "Curve",
         line = "Line"

    static let defaultEdgeStyle: Self = .curve
}

extension StitchStore {
    static func appEdgeStyleChanged(newEdgeStyle: EdgeStyle) {
        // log("AppEdgeStyleChangedEvent: newEdgeStyle: \(newEdgeStyle)")
        // log("AppEdgeStyleChangedEvent: state.edgeStyle was: \(state.edgeStyle)")
        // log("AppEdgeStyleChangedEvent: state.edgeStyle is now: \(state.edgeStyle)")

        // Also update the UserDefaults:
        UserDefaults.standard.setValue(
            newEdgeStyle.rawValue,
            forKey: StitchAppSettings.EDGE_STYLE.rawValue)
    }
}

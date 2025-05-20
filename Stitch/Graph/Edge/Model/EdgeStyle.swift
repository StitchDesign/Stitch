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

struct AppEdgeStyleChangedEvent: AppEvent {
    let newEdgeStyle: EdgeStyle

    func handle(state: AppState) -> AppResponse {
        // log("AppEdgeStyleChangedEvent: newEdgeStyle: \(newEdgeStyle)")
        var state = state
        // log("AppEdgeStyleChangedEvent: state.edgeStyle was: \(state.edgeStyle)")
        state.edgeStyle = newEdgeStyle
        // log("AppEdgeStyleChangedEvent: state.edgeStyle is now: \(state.edgeStyle)")

        // Also update the UserDefaults:
        UserDefaults.standard.setValue(
            newEdgeStyle.rawValue,
            forKey: SAVED_EDGE_STYLE_KEY_NAME)

        return .stateOnly(state)
    }
}

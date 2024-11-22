//
//  DrawerState.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/26/22.
//

import SwiftUI
import StitchSchemaKit

// called when drawer-toggle button pressed
struct ShowDrawer: AppEvent {
    func handle(state: AppState) -> AppResponse {
        var state = state
        state.isShowingDrawer = true
        return .stateOnly(state)
    }
}

struct HideDrawer: AppEvent {
    func handle(state: AppState) -> AppResponse {
        var state = state
        state.isShowingDrawer = false
        return .stateOnly(state)
    }
}

//
//  AppState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/19/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// need two different AppState types:
// - AppStateFrontScreen = app state without project
// - AppStateWithLoadedProject = app state with current project
// TODO: this is deprecated
struct AppState: Equatable {

    var edgeStyle: EdgeStyle = .defaultEdgeStyle

    // TODO: should be properly persisted
    var appTheme: StitchTheme = .defaultTheme

    var isShowingDrawer = false

    // Tracks ID of project which has a title that's currently getting modified
    var projectIdForTitleEdit: GraphId?
}

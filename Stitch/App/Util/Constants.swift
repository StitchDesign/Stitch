//
//  Constants.swift
//  prototype
//
//  Created by cjc on 1/18/21.
//

import AVKit
import Foundation
import SwiftUI
import StitchSchemaKit

/* ----------------------------------------------------------------
 -- MARK: COLORS
 ---------------------------------------------------------------- */

let MODAL_BACKGROUND_COLOR = Color.black.opacity(0.4)

let APP_BACKGROUND_COLOR: Color = Color(.appBackground)

let DEFAULT_FLOATING_WINDOW_COLOR = StitchDocument.defaultBackgroundColor

let INSERT_NODE_MENU_BACKGROUND = Color(.insertNodeMenuBackground)

let INSERT_NODE_SEARCH_BACKGROUND = INSERT_NODE_MENU_BACKGROUND // Color(.insertNodeSearchMenu)

extension Color {
    static let THEMED_TITLE_FONT_COLOR: Color = Color(.titleFont)
}

let trueColor = Color.white
let falseColor = Color.black

/* ----------------------------------------------------------------
 -- MARK: MEASUREMENTS
 ---------------------------------------------------------------- */

let NODE_POSITION_STAGGER_SIZE: CGFloat = 50

let PREVIEW_SHOWN_DEFAULT_STATE: Bool = true

let PROJECTSVIEW_ITEM_TEXT_HEIGHT: CGFloat = 24
let PROJECTSVIEW_ITEM_TEXT_PADDING: CGFloat = 4

let PREVIEW_WINDOW_Y_PADDING: CGFloat = 16

let DEFAULT_TIMESCALE = CMTimeScale(NSEC_PER_SEC)

/* ----------------------------------------------------------------
 -- MARK: NAVIGATION BAR
 ---------------------------------------------------------------- */

let TOPBAR_SPACING: CGFloat = 4

/* ----------------------------------------------------------------
 -- MARK: PROJECTS HOME VIEW
 ---------------------------------------------------------------- */

// let NEW_PROJECT_ICON_NAME: IconName = .svgIcon("New Doc")
let NEW_PROJECT_ICON_NAME: IconName = .sfSymbol(.NEW_PROJECT_SF_SYMBOL_NAME)

let EXPORT_LOGS_ICON_NAME: IconName = .sfSymbol("scroll")

@MainActor
let SHOW_APP_SETTINGS = { dispatch(ShowAppSettingsSheet()) }
let APP_SETTINGS_ICON_NAME: IconName = PROJECT_SETTINGS_ICON_NAME

@MainActor
let SHOW_APP_SETTINGS_ACTION = { dispatch(ShowAppSettingsSheet()) }

@MainActor
let EXPORT_LOGS_ACTION = { dispatch(LogsExportStarted()) }

@MainActor
let DELETE_ALL_PROJECTS_ALERT_ACTION = { dispatch(ShowDeleteAllProjectsConfirmation()) }

/* ----------------------------------------------------------------
 -- MARK: GRAPH VIEW: LEFT SIDE
 ---------------------------------------------------------------- */

// Looks better on Catalyst nav-bar than the SVG asset
let TOP_BAR_MENU_ICON_NAME: IconName =  .sfSymbol("ellipsis.circle")

/* ----------------------------------------------------------------
 -- MARK: GRAPH VIEW: RIGHT SIDE (CATALYST), MENU (IPAD)
 ---------------------------------------------------------------- */

let PREVIEW_HIDE_ICON_NAME: IconName = .svgIcon("calm 1")
@MainActor
let PREVIEW_SHOW_TOGGLE_ACTION = { dispatch(TogglePreviewWindow()) }

let FILE_IMPORT_LABEL = "Import File"
let FILE_IMPORT_ICON_NAME: IconName = .svgIcon("Doc")
// let FILE_IMPORT_ICON_NAME: IconName = .sfSymbol("doc")

@MainActor
let FILE_IMPORT_ACTION = { dispatch(ShowFileImportModal()) }

@MainActor
let INSERT_NODE_ACTION = { dispatch(ToggleInsertNodeMenu()) }

@MainActor
let RESTART_PROTOTYPE_ACTION = { dispatch(PrototypeRestartedAction()) }

@MainActor
let PREVIEW_FULL_SCREEN_ACTION = { dispatch(ToggleFullScreenEvent()) }

let UNDO_ICON_LABEL = "Undo"
let UNDO_ICON_NAME: IconName = .svgIcon("Undo")
@MainActor
let UNDO_ACTION = { dispatch(UndoEvent()) }

let REDO_ICON_LABEL = "Redo"
let REDO_ICON_NAME: IconName = .svgIcon("Redo")
@MainActor
let REDO_ACTION = { dispatch(RedoEvent()) }

let PROJECT_SETTINGS_LABEL = "Settings"
let PROJECT_SETTINGS_ICON_NAME: IconName = .sfSymbol(.SETTINGS_SF_SYMBOL_NAME)
@MainActor
let PROJECT_SETTINGS_ACTION = { dispatch(ShowProjectSettingsSheet()) }

/* ----------------------------------------------------------------
 -- MARK: GESTURES
 ---------------------------------------------------------------- */

let SCREEN_TOUCH_ID = NSNumber(value: UITouch.TouchType.direct.rawValue)
let TRACKPAD_TOUCH_ID = NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)

let GESTURE_VIEW_TAG = UUID().hashValue

/* ----------------------------------------------------------------
 -- MARK: OTHER
 ---------------------------------------------------------------- */

let IPAD_PREVIEW_DEVICE_NAME = PreviewDevice(rawValue: "iPad Pro (11-inch) (3rd generation)")

let nanoSecondsInSecond = 1000000000
let nanoSecondsInMillisecond = 1000000

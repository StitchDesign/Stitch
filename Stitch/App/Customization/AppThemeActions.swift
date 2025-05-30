//
//  AppThemeActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation
import SwiftUI

struct AppThemeChangedEvent: AppEvent {
    let newTheme: StitchTheme

    func handle(state: AppState) -> AppResponse {
        // log("AppThemeChangedEvent: newTheme.themeData: \(newTheme.themeData)")
        var state = state
        // log("AppThemeChangedEvent: state.appTheme was: \(state.appTheme)")
        state.appTheme = newTheme
        // log("AppThemeChangedEvent: state.appTheme is now: \(state.appTheme)")

        // Also update the UserDefaults:
        UserDefaults.standard.setValue(
            newTheme.rawValue,
            forKey: SAVED_APP_THEME_KEY_NAME)

        // Note: Apple sample 'app icon change' project does not immediately change app icon on iPad: https://developer.apple.com/documentation/xcode/configuring_your_app_to_use_alternate_app_icons#4047495
        // log("AppThemeChangedEvent: UIApplication.shared.supportsAlternateIcons: \(UIApplication.shared.supportsAlternateIcons)")

        UIApplication
            .shared
            .setAlternateIconName(newTheme.appIconName) { (maybeError: Error?) in
                log("AppThemeChangedEvent: when changing app icon to \(newTheme.appIconName), encountered error: \(String(describing: maybeError))")
            }

        return .stateOnly(state)
    }
}

extension Bool {
    static let defaultIsOptionRequiredForShortcuts = true
    static let defaultCanShareAIRetries = true
}

struct OptionRequiredForShortcutsChanged: StitchStoreEvent {

    let newValue: Bool
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        
        log("OptionRequiredForShortcutsChanged: store.isOptionRequiredForShortcut was: \(store.isOptionRequiredForShortcut)")
        log("OptionRequiredForShortcutsChanged: newValue.description: \(newValue.description)")
        store.isOptionRequiredForShortcut = newValue
        log("OptionRequiredForShortcutsChanged: store.isOptionRequiredForShortcut is now: \(store.isOptionRequiredForShortcut)")
        
        UserDefaults.standard.setValue(
            newValue.description,
            forKey: SAVED_IS_OPTION_REQUIRED_FOR_SHORTCUTS_KEY_NAME)
        
        return .shouldPersist
    }
}

struct CanShareAIRetriesChanged: StitchStoreEvent {

    let newValue: Bool
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        
        log("CanShareAIRetriesChanged: store.isOptionRequiredForShortcut was: \(store.canShareAIRetries)")
        log("CanShareAIRetriesChanged: newValue.description: \(newValue.description)")
        store.canShareAIRetries = newValue
        log("CanShareAIRetriesChanged: store.canShareAIRetries is now: \(store.canShareAIRetries)")
        
        UserDefaults.standard.setValue(
            newValue.description,
            forKey: SAVED_CAN_SHARE_AI_RETRIES_KEY_NAME)
        
        return .shouldPersist
    }
}

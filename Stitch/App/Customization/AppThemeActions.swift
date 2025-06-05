//
//  AppThemeActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation
import SwiftUI

extension StitchStore {
    @MainActor
    static func appThemeChanged(newTheme: StitchTheme) {
        // log("AppThemeChangedEvent: newTheme.themeData: \(newTheme.themeData)")
        // log("AppThemeChangedEvent: state.appTheme was: \(state.appTheme)")
        // log("AppThemeChangedEvent: state.appTheme is now: \(state.appTheme)")

        // Also update the UserDefaults:
        UserDefaults.standard.setValue(
            newTheme.rawValue,
            forKey: StitchAppSettings.APP_THEME.rawValue)

        // Note: Apple sample 'app icon change' project does not immediately change app icon on iPad: https://developer.apple.com/documentation/xcode/configuring_your_app_to_use_alternate_app_icons#4047495
        // log("AppThemeChangedEvent: UIApplication.shared.supportsAlternateIcons: \(UIApplication.shared.supportsAlternateIcons)")

        UIApplication
            .shared
            .setAlternateIconName(newTheme.appIconName) { (maybeError: Error?) in
                log("AppThemeChangedEvent: when changing app icon to \(newTheme.appIconName), encountered error: \(String(describing: maybeError))")
            }
    }
}

extension Bool {
    static let defaultIsOptionRequiredForShortcuts = true
}

struct OptionRequiredForShortcutsChanged: StitchStoreEvent {

    let newValue: Bool
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        
        let oldValue = UserDefaults.standard.value(forKey: StitchAppSettings.IS_OPTION_REQUIRED_FOR_SHORTCUTS.rawValue)
        log("OptionRequiredForShortcutsChanged: store.isOptionRequiredForShortcut was: \(oldValue ?? "none")")
        log("OptionRequiredForShortcutsChanged: newValue.description: \(newValue.description)")
        log("OptionRequiredForShortcutsChanged: store.isOptionRequiredForShortcut is now: \(newValue)")
        
        UserDefaults.standard.setValue(
            newValue.description,
            forKey: StitchAppSettings.IS_OPTION_REQUIRED_FOR_SHORTCUTS.rawValue)
        
        return .noChange
    }
}

struct CanShareAIData: StitchStoreEvent {

    let newValue: Bool
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        let oldValue = UserDefaults.standard.value(forKey: StitchAppSettings.CAN_SHARE_AI_DATA.rawValue)
        
        log("CanShareAIRetriesChanged: store.isOptionRequiredForShortcut was: \(oldValue ?? "none")")
        log("CanShareAIRetriesChanged: newValue.description: \(newValue.description)")
        log("CanShareAIRetriesChanged: store.canShareAIRetries is now: \(newValue)")
        
        UserDefaults.standard.setValue(
            newValue,
            forKey: StitchAppSettings.CAN_SHARE_AI_DATA.rawValue)
        
        return .noChange
    }
}

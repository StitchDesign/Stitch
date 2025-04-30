//
//  EnvironmentValues.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/7/23.
//

import SwiftUI
import StitchSchemaKit

struct ViewFrameKey: EnvironmentKey {
    static let defaultValue = CGRect()
}

struct AppThemeKey: EnvironmentKey {
    static let defaultValue: StitchTheme = .defaultTheme
}

struct EdgeStyleKey: EnvironmentKey {
    static let defaultValue: EdgeStyle = .defaultEdgeStyle
}

struct SafeAreaInsetsEnvironmentKey: EnvironmentKey, Hashable {
    static let defaultValue = SafeAreaInsets()
}

extension EnvironmentValues {
    var viewframe: CGRect {
        get { self[ViewFrameKey.self] }
        set { self[ViewFrameKey.self] = newValue }
    }

    var appTheme: StitchTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }

    var edgeStyle: EdgeStyle {
        get { self[EdgeStyleKey.self] }
        set { self[EdgeStyleKey.self] = newValue }
    }
    
    var safeAreaInsets: SafeAreaInsets {
        get { self[SafeAreaInsetsEnvironmentKey.self] }
        set { self[SafeAreaInsetsEnvironmentKey.self] = newValue }
    }
}

struct StitchFocusedField: FocusedValueKey {
    typealias Value = FocusedUserEditField
}

/*
 TODO: something feels slightly off about .focusedValue; we can intermittently end up with non-nil .focusedValue in cases where we would not expect to have a focused field; this breaks various shortcuts.

 Try to figure out why having multiple text-fields on the screen at once
 (e.g. when we used to use an editable-text-field for every node title)
 makes it easier to end up with a non-nil focusedField even though none of the fields ought to be focused?
 */
extension FocusedValues {
    var focusedField: StitchFocusedField.Value? {
        get { self[StitchFocusedField.self] }
        set {
            // log("FocusedValues: focusedField: set: self[StitchFocusedField.self]: \(self[StitchFocusedField.self])")
            // log("FocusedValues: focusedField: set: newValue: \(newValue)")
            self[StitchFocusedField.self] = newValue
        }
    }
}

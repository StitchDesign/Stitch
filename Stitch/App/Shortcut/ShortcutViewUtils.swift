//
//  SwiftUIShortcutView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/22.
//

import SwiftUI
import StitchSchemaKit

/*
 SwiftUI effectively treats .keyboardShortcut as
 another way of triggering a button interaction;
 hence we use hidden buttons as listeners,
 and give the button the desired redux callback.
 */
struct SwiftUIShortcutView: View {
    var title: String = ""
    let key: KeyEquivalent
    var eventModifiers: EventModifiers = [.command]
    var disabled: Bool = false
    let action: @MainActor () -> Void

    var body: some View {
        Button(title) { action() }
            // implicitly "CMD + key", unless eventModifiers = []
            .keyboardShortcut(key, modifiers: eventModifiers)
            .disabled(disabled)
    }
}

/// Registers arrow key bindings
extension StitchHostingController {
    static func createKeyBinding(_ key: String,
                                 modifierFlags: UIKeyModifierFlags = [],
                                 action: Selector) -> UIKeyCommand {
        let keyCommand = UIKeyCommand(input: key,
                                      modifierFlags: modifierFlags,
                                      action: action)
        keyCommand.wantsPriorityOverSystemBehavior = true
        return keyCommand
    }
}


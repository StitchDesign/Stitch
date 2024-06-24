//
//  StitchHostingController.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation
import SwiftUI
import UIKit

/// Used by various SwiftUI views to inject a view into a view controller
class StitchHostingController<T: View>: UIHostingController<T> {
    let ignoresSafeArea: Bool
    let ignoreKeyCommands: Bool
    var usesArrowKeyBindings: Bool = false
    let name: String

    init(rootView: T,
         ignoresSafeArea: Bool,
         ignoreKeyCommands: Bool,
         usesArrowKeyBindings: Bool = false,
         name: String) {
        self.ignoresSafeArea = ignoresSafeArea
        self.ignoreKeyCommands = ignoreKeyCommands
        self.usesArrowKeyBindings = usesArrowKeyBindings
        self.name = name
        super.init(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupFullscreenConstraints(ignoresSafeArea: self.ignoresSafeArea)

        self.view.backgroundColor = .clear
    }

    // Never called?
    //    override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    //        log("KEY: StitchHostingController: pressesChanged")
    //        //        super.pressesChanged(presses, with: event)
    //    }

    #if targetEnvironment(macCatalyst)
    /// Fixes issue where keypresses can be stuck to toggled on Mac (repro with CMD + SHIFT + 5 screen sharing)
    @MainActor
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.activeAppearance == .active {
            dispatch(KeyModifierReset())
        }
    }
    #endif

    override func pressesBegan(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        // log("KEY: StitchHostingController: name: \(name): pressesBegan: presses.first?.key: \(presses.first?.key)")
        presses.first?.key.map(keyPressed)
        //        super.pressesBegan(presses, with: event)

        /*
         HACK for Option key on Mac Catalyst:

         Some UIResponder along the chain dispatches a `pressesCancelled` event whenever Option is pressed;
         thus we get `pressesCancelled` happening immediately after `pressesBegan`,
         which defeats our ability to listen for Option key press vs release.

         So, we simply don't pass the Option key's pressesBegan along the chain.
         */
        #if targetEnvironment(macCatalyst)
        if let key = presses.first?.key,
           !self.isOptionKey(key) {
            super.pressesBegan(presses, with: event)
        }
        #else
        super.pressesBegan(presses, with: event)
        #endif
    }

    override func pressesEnded(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        // log("KEY: StitchHostingController: name: \(name): pressesEnded: presses.first?.key: \(presses.first?.key)")
        presses.first?.key.map(keyReleased)
        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>,
                                   with event: UIPressesEvent?) {
        // log("KEY: StitchHostingController: name: \(name): pressesCancelled: presses.first?.key: \(presses.first?.key)")
        presses.first?.key.map(keyReleased)
        super.pressesCancelled(presses, with: event)
    }

    func keyPressed(_ key: UIKey) {
        // log("KEY: StitchHostingController: name: \(name): keyPressed: key: \(key)")
        
        // TODO: key-modifiers (Tab, Shift etc.) and key-characters are not exclusive
        if let modifiers = key.asStitchKeyModifiers {
            dispatch(KeyModifierPressBegan(modifiers: modifiers))
        } else if let keyPress = key.characters.first {
            dispatch(KeyCharacterPressBegan(char: keyPress))
        }
    }

    func keyReleased(_ key: UIKey) {
        // log("KEY: StitchHostingController: name: \(name): keyReleased: key: \(key)")
        if let modifiers = key.asStitchKeyModifiers {
            dispatch(KeyModifierPressEnded(modifiers: modifiers))
        } else if let keyPress = key.characters.first {
            dispatch(KeyCharacterPressEnded(char: keyPress))
        }
    }

    func isOptionKey(_ key: UIKey) -> Bool {
        key.keyCode == .keyboardLeftAlt
            || key.keyCode == .keyboardRightAlt
    }
    
    // MARK: arrow key callbacks

    @objc func arrowKeyUp(_ sender: UIKeyCommand) {
        dispatch(ArrowKeyPressed(arrowKey: .up))
    }

    @objc func arrowKeyDown(_ sender: UIKeyCommand) {
        dispatch(ArrowKeyPressed(arrowKey: .down))
    }

    @objc func arrowKeyLeft(_ sender: UIKeyCommand) {
        dispatch(ArrowKeyPressed(arrowKey: .left))
    }

    @objc func arrowKeyRight(_ sender: UIKeyCommand) {
        dispatch(ArrowKeyPressed(arrowKey: .right))
    }

    @objc func escKey(_ sender: UIKeyCommand) {
        dispatch(ESCKeyPressed())
    }

    @objc func zoomInKey(_ sender: UIKeyCommand) {
        dispatch(GraphZoomedIn())
    }

    @objc func zoomOutKey(_ sender: UIKeyCommand) {
        dispatch(GraphZoomedOut())
    }

    @objc func noOp(_ sender: UIKeyCommand) {}

    let arrowKeyBindings: [UIKeyCommand] = [

        // Up and Down arrows override system bevaior, so that we can scroll through insert-node-menu;
        createKeyBinding(ArrowKey.up.uiKeyCommand,
                         action: #selector(arrowKeyUp(_:))),
        createKeyBinding(ArrowKey.down.uiKeyCommand,
                         action: #selector(arrowKeyDown(_:))),

        // ... but keep system behavior for left and right, so that we can move through an input.
        UIKeyCommand(action: #selector(arrowKeyLeft(_:)),
                     input: ArrowKey.left.uiKeyCommand),

        UIKeyCommand(action: #selector(arrowKeyRight(_:)),
                     input: ArrowKey.right.uiKeyCommand)
    ]

    let escKeyBinding = createKeyBinding(UIKeyCommand.inputEscape,
                                         action: #selector(escKey(_:)))

    let optionKeyBinding = UIKeyCommand(input: .empty,
                                        modifierFlags: .alternate,
                                        action: #selector(noOp(_:)))

    let zoomInBinding = UIKeyCommand(input: "=", modifierFlags: .command, action: #selector(zoomInKey(_:)))

    let zoomOutBinding = UIKeyCommand(input: "-", modifierFlags: .command, action: #selector(zoomOutKey(_:)))

    func asUIKeyCommand(_ letter: String, shift: Bool = false) -> UIKeyCommand {
        UIKeyCommand(input: letter,
                     modifierFlags: shift ? [.shift] : [],
                     action: #selector(noOp(_:)))
    }

    var qwertyCommands: [UIKeyCommand] {
        Qwerty.qwertyLetters.map { asUIKeyCommand($0) }
            + Qwerty.qwertyNumbers.map { asUIKeyCommand($0) }
            + Qwerty.qwertyOther.map { asUIKeyCommand($0) }
    }

    var qwertyShiftCommands: [UIKeyCommand] {
        Qwerty.qwertyLetters.map { asUIKeyCommand($0, shift: true) }
            + Qwerty.qwertyNumbers.map { asUIKeyCommand($0, shift: true) }
            + Qwerty.qwertyOther.map { asUIKeyCommand($0, shift: true) }
    }

    /// Process certain keyboard events. This is the only way we can detect just arrow keys without a modifier like CMD.
    override var keyCommands: [UIKeyCommand]? {

        if !ignoreKeyCommands {
            let bindings = [escKeyBinding, zoomInBinding, zoomOutBinding, optionKeyBinding] + qwertyCommands + qwertyShiftCommands

            if usesArrowKeyBindings {
                return arrowKeyBindings + bindings
            } else {
                return bindings
            }

        } else {
            return []
        }
    }

}

/// A very simple view implementation of a `StitchHostingController`.
struct StitchHostingControllerView<T: View>: View {
    let ignoreKeyCommands: Bool
    var usesArrowKeyBindings: Bool = false
    let name: String
    @ViewBuilder var view: () -> T

    var body: some View {
        StitchHostingControllerViewRepresentable(
            view: view(),
            ignoreKeyCommands: ignoreKeyCommands,
            usesArrowKeyBindings: usesArrowKeyBindings,
            name: name)
    }
}

/// A very simple view implementation of a `StitchHostingController`.
struct StitchHostingControllerViewRepresentable<T: View>: UIViewControllerRepresentable {
    let view: T
    let ignoreKeyCommands: Bool
    var usesArrowKeyBindings: Bool = false
    let name: String

    func makeUIViewController(context: Context) -> StitchHostingController<T> {
        StitchHostingController(rootView: view,
                                ignoresSafeArea: false,
                                ignoreKeyCommands: ignoreKeyCommands,
                                usesArrowKeyBindings: usesArrowKeyBindings,
                                name: name)
    }

    func updateUIViewController(_ uiViewController: StitchHostingController<T>, context: Context) {
        uiViewController.rootView = view
    }
}

//
//  StitchHostingController.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation
import SwiftUI
import UIKit

/*
 We use UIHostingController key-listening when:
 
 1. listening for any key press, e.g. graph listening for TABs on the graph or in a field (node field, inspector field etc.) or for a keyboard patch node
 2. listening only for specific keys, e.g. arrow keys in the insert node menu searchbar).
 3. listening only in specific UI situations, e.g. listening to TAB presses when preview window fullscreen (NOTE: No longer relevant?)
 
 
 We use UIHostingController more generally to:
 
 1. apply UIKit gestures
 2. solve certain bugs, e.g. UIKitWrapper around preview window
 

 Current unexpected / undesired behavior:
 
 1. key-released events firing before a key-pressed event and/or fired while key still held down
 2. multiple key listeners responding to certain key modifiers but not others (e.g. `TAB` but not `Option`)
 3. PreviewContent key listening is required for keyboard patch nodes
 

 Current solutions / workarounds:
 
 1. rely on UIKit gestures for detecting `Option`, `Shift` during a tap or drag etc. (NOTE: relying on UITapGestureRecognizer for sidebar items has seemed to make tap less reliable?)
 
 
 Multiple ways to solve this:
 
 1. be smarter about when and where we use key listening; e.g. maybe we need a UIHostingController for gesture but not for key listening
 2. handle conflicting key-listening logic at the redux level; helpful for more complicated scenarios where we need to look at other state to determine how to handle a key
 
 
 Note: `ignoresKeyCommands = true` does not prevent us from listening to key modifier presses like TAB.
 */
enum KeyListenerName: String, Equatable {
    case previewWindow, // PreviewContent
         insertNodeMenuSearchbar, // InsertNodeMenuSearchBar
         mainGraph, // ContentView i.e. "nodeAndMenu"
         sheetView,
         fullScreenGestureRecognzer, // full screen preview window
         uiKitTappableWrapper, // variety of use cases?
         sidebarListItem // "SidebarListItemGestureRecognizerView"
}

/// Used by various SwiftUI views to inject a view into a view controller
class StitchHostingController<T: View>: UIHostingController<T> {
    let ignoresSafeArea: Bool
    let ignoreKeyCommands: Bool
    
    // i.e. only intended for Tab, Shift + Tab, Arrow Keys; just for flyouts at the moment
    let isOnlyForTextFieldHelp: Bool
    
    // TODO: better to just pass `weak var graph: GraphState` here? Avoids having to update this variable in the various `updateUIView` functions of views that consume SHC
    var inputTextFieldFocused: Bool
    
    var usesArrowKeyBindings: Bool = false
    let name: KeyListenerName

    init(rootView: T,
         ignoresSafeArea: Bool,
         ignoreKeyCommands: Bool,
         isOnlyForTextFieldHelp: Bool,
         inputTextFieldFocused: Bool,
         usesArrowKeyBindings: Bool = false,
         name: KeyListenerName) {
        self.ignoresSafeArea = ignoresSafeArea
        self.ignoreKeyCommands = ignoreKeyCommands
        self.isOnlyForTextFieldHelp = isOnlyForTextFieldHelp
        self.inputTextFieldFocused = inputTextFieldFocused
        self.usesArrowKeyBindings = usesArrowKeyBindings
        self.name = name
        super.init(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Hides the navigation bar UI, which is needed in the layer inspector view, where an invisible view
    /// blocks UI interactions.
    /// Source: https://stackoverflow.com/a/71131226/7396787
    override var navigationController: UINavigationController? {
        nil
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

     // TODO: this seems to be too aggressive -- often seems to change when we're tapping in the left sidebar
    
    //    #if targetEnvironment(macCatalyst)
    //    /// Fixes issue where keypresses can be stuck to toggled on Mac (repro with CMD + SHIFT + 5 screen sharing)
    //    @MainActor
    //    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    //        if previousTraitCollection?.activeAppearance == .active {
    //            log("stitch hosting controller will fire KeyModifierReset")
    //            dispatch(KeyModifierReset())
    //        }
    //    }
    //    #endif

    @MainActor
    override func pressesBegan(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        // log("KEY: StitchHostingController: name: \(name): pressesBegan: presses.first?.key: \(presses.first?.key)")
        presses.first?.key.map(keyPressed)
        
        // If we don't have a key, we can't check whether we should
        // prevent this press from being passed down the responder chain.
        guard let key = presses.first?.key else {
            // log("KEY: StitchHostingController: name: \(name): pressesBegan: no key")
            super.pressesBegan(presses, with: event)
            return
        }
        
        // Do not pass on up or down arrows if an input's text-field is currently focused.
        // Prevents up- and down-arrow keys from jumping the cursor to the start or end of the text when we merely want to increment or decrement the focused field's value.
        let isUpOrDownArrow = (key.keyCode == .keyboardUpArrow || key.keyCode == .keyboardDownArrow)
        if isUpOrDownArrow && self.inputTextFieldFocused {
            // log("KEY: StitchHostingController: name: \(name): pressesBegan: will not pass arrow key down responder chain")
            return
        }
        
#if targetEnvironment(macCatalyst)
        /*
         HACK for Option key on Mac Catalyst:
         
         Some UIResponder along the chain dispatches a `pressesCancelled` event whenever Option is pressed;
         thus we get `pressesCancelled` happening immediately after `pressesBegan`,
         which defeats our ability to listen for Option key press vs release.
         
         So, we simply don't pass the Option key's pressesBegan along the chain.
         
         TODO: also never pass on the shift key?
         */
        if self.isOptionKey(key) {
            // log("KEY: StitchHostingController: name: \(name): pressesBegan: option key held")
            return
        }
#endif
        
        // If we did not exit early,
        super.pressesBegan(presses, with: event)
    }

    @MainActor
    override func pressesEnded(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        // log("KEY: StitchHostingController: name: \(name): pressesEnded: presses.first?.key: \(presses.first?.key)")
        presses.first?.key.map(keyReleased)
        super.pressesEnded(presses, with: event)
    }

    @MainActor
    override func pressesCancelled(_ presses: Set<UIPress>,
                                   with event: UIPressesEvent?) {
        // log("KEY: StitchHostingController: name: \(name): pressesCancelled: presses.first?.key: \(presses.first?.key)")
        presses.first?.key.map(keyReleased)
        super.pressesCancelled(presses, with: event)
    }

    @MainActor
    func keyPressed(_ key: UIKey) {
        // log("KEY: StitchHostingController: name: \(name): keyPressed: key: \(key)")
                
        if key.keyCode == .keyboardUpArrow && self.inputTextFieldFocused {
            // log("KEY: StitchHostingController: name: \(name): keyPressed: UP ARROW")
            dispatch(ArrowPressedWhileInputTextFieldFocused(wasUpArrow: true))
            return
        }
        
        if key.keyCode == .keyboardDownArrow && self.inputTextFieldFocused {
            // log("KEY: StitchHostingController: name: \(name): keyPressed: DOWN ARROW")
            dispatch(ArrowPressedWhileInputTextFieldFocused(wasUpArrow: false))
            return
        }
        
        // TODO: key-modifiers (Tab, Shift etc.) and key-characters are not exclusive
        if let modifiers = key.asStitchKeyModifiers {
            dispatch(KeyModifierPressBegan(name: self.name, modifiers: modifiers))
        }
        
        // else
        if let keyPress = key.characters.first,
                  // Don't listen to random char presses if we're only in the flyout or search bar etc.
                    !self.isOnlyForTextFieldHelp {
            dispatch(KeyCharacterPressBegan(char: keyPress))
        }
    }

    @MainActor
    func keyReleased(_ key: UIKey) {
        // log("KEY: StitchHostingController: name: \(name): keyReleased: key: \(key)")
        if let modifiers = key.asStitchKeyModifiers {
            dispatch(KeyModifierPressEnded(modifiers: modifiers))
        } else if let keyPress = key.characters.first,
                    !self.isOnlyForTextFieldHelp {
            dispatch(KeyCharacterPressEnded(char: keyPress))
        }
    }

    func isOptionKey(_ key: UIKey) -> Bool {
        key.keyCode == .keyboardLeftAlt
            || key.keyCode == .keyboardRightAlt
    }
    
    // MARK: arrow key callbacks

    @objc func arrowKeyUp(_ sender: UIKeyCommand) {
        // log("KEY: StitchHostingController: name: \(name): arrowKeyUp")
        dispatch(ArrowKeyPressed(arrowKey: .up))
    }

    @objc func arrowKeyDown(_ sender: UIKeyCommand) {
        // log("KEY: StitchHostingController: name: \(name): arrowKeyDown")
        dispatch(ArrowKeyPressed(arrowKey: .down))
    }

    @objc func arrowKeyLeft(_ sender: UIKeyCommand) {
        // log("KEY: StitchHostingController: name: \(name): arrowKeyLeft")
        dispatch(ArrowKeyPressed(arrowKey: .left))
    }

    @objc func arrowKeyRight(_ sender: UIKeyCommand) {
        // log("KEY: StitchHostingController: name: \(name): arrowKeyRight")
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
            let bindings = [escKeyBinding, zoomInBinding, zoomOutBinding, optionKeyBinding]
            /*
              TODO: dig deeper here, so we can use SwiftUI shortcuts consistently whether Option is required or note. For now, we want to be cautious about changing our keypress logic.
             
             UIKeyCommands seem to override modifier-free SwiftUI shortcuts (i.e. `.keyboardShortcut("a", modifiers: [])`;
             but without UIKeyCommands we seem to receive a pressesBegan and pressesEnded at the same time?
             */
            + qwertyCommands + qwertyShiftCommands

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
    let inputTextFieldFocused: Bool
    var usesArrowKeyBindings: Bool = false
    let name: KeyListenerName
    @ViewBuilder var view: () -> T

    var body: some View {
        StitchHostingControllerViewRepresentable(
            view: view(),
            ignoreKeyCommands: ignoreKeyCommands,
            inputTextFieldFocused: inputTextFieldFocused,
            usesArrowKeyBindings: usesArrowKeyBindings,
            name: name)
    }
}

/// A very simple view implementation of a `StitchHostingController`.
struct StitchHostingControllerViewRepresentable<T: View>: UIViewControllerRepresentable {
    let view: T
    let ignoreKeyCommands: Bool
    let inputTextFieldFocused: Bool
    var usesArrowKeyBindings: Bool = false
    let name: KeyListenerName

    func makeUIViewController(context: Context) -> StitchHostingController<T> {
        StitchHostingController(rootView: view,
                                ignoresSafeArea: false,
                                ignoreKeyCommands: ignoreKeyCommands,
                                isOnlyForTextFieldHelp: false, // Actually should be true, since this is only for node menu ?
                                inputTextFieldFocused: inputTextFieldFocused,
                                usesArrowKeyBindings: usesArrowKeyBindings,
                                name: name)
    }

    func updateUIViewController(_ uiViewController: StitchHostingController<T>, context: Context) {
        uiViewController.rootView = view
        uiViewController.inputTextFieldFocused = self.inputTextFieldFocused
    }
}

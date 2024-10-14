//
//  KeypressState.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/14/22.
//

import UIKit

struct KeyPressState: Equatable, Hashable {
    
    // TODO: figure out a better way to listen for key presses, i.e. to not lose shift-key
    var shiftHeldDuringGesture: Bool = false
    
    // modifiers and non-character keys like `TAB`
    var modifiers = Set<StitchKeyModifier>()
    
    // character keys like "a", "Q", or even space " "
    var characters = Set<Character>()
}

extension KeyPressState {
    var isOptionPressed: Bool {
        // TODO: Should just be `self.modifiers.contains(.option)` ?
        self.modifiers == Set([.option])
    }

    var isSpacePressed: Bool {
        self.characters.contains { $0 == " " }
    }

    var isCommandPressed: Bool {
        self.modifiers.contains(.cmd)
    }
    
    var isShiftPressed: Bool {
        self.modifiers.contains(.shift)
    }
    
    var isTabPressed: Bool {
        self.modifiers.contains(.tab)
    }
}

/// Effectively any non-character key, such as Shift or Tab or Cmd, but not "a" or "p" etc.
enum StitchKeyModifier: CaseIterable {
    case capslock
    case shift
    case ctrl
    case cmd
    case option
    case tab
}

extension UIKey {
    
    // Note: a single UIKey may have a non-character key from modifierFlags and/or keyCode.
    var asStitchKeyModifiers: Set<StitchKeyModifier>? {
        var acc = Set<StitchKeyModifier>()
        
        if let modifierFromFlag = self.stitchKeyModifierFromFlag {
            acc.insert(modifierFromFlag)
        }
        
        if let modifierFromKeyCode = self.stitchKeyModifierFromKeyCode {
            acc.insert(modifierFromKeyCode)
        }
        
        return acc.isEmpty ? nil : acc
    }
    
    // TODO: if every key on the keyboard has at least one keycode, can we always use the UIKey.keyCode rather than UIKey.modifierFlags?
    var stitchKeyModifierFromKeyCode: StitchKeyModifier? {
        switch self.keyCode {
        case .keyboardTab:
            return .tab
        default:
            return nil
        }
    }
    
    var stitchKeyModifierFromFlag: StitchKeyModifier? {
        switch self.modifierFlags {
        case .alphaShift:
            return .capslock
        case .alternate:
            return .option
        case .command:
            return .cmd
        case .control:
            return .ctrl
        case .numericPad:
            return nil
        case .shift:
            return .shift
        default:
            // log("UIKeyModifierFlags: default: \(self.modifierFlags)")
            return nil
        }
    }
}

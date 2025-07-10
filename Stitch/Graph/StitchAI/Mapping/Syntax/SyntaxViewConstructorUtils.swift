//
//  SyntaxViewConstructorUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/10/25.
//

import Foundation
import SwiftUI
import UIKit


extension AttributedString {
/// Returns only the textual content (attributes are discarded).
var plainText: String { self.description }   // `.description` flattens to String
}

extension LocalizedStringKey {
/// Best‑effort: resolves through the app’s main bundle; falls back to the key itself.
var resolved: String {
    let keyString = String(describing: self)   // mirrors what the dev wrote
    return NSLocalizedString(keyString,
                             bundle: .main,
                             value: keyString,
                             comment: "")
}
}

// ── Alignment → Anchoring helpers ───────────────────────────────────────

extension VerticalAlignment {
    var toAnchoring: Anchoring {
        switch self {
        case .top:               return .topCenter
        case .bottom:            return .bottomCenter
        case .firstTextBaseline: return .topCenter       // best-effort
        case .lastTextBaseline:  return .bottomCenter    // best-effort
        default:                 return .centerCenter    // .center
        }
    }
}

extension HorizontalAlignment {
    var toAnchoring: Anchoring {
        switch self {
        case .leading:  return .centerLeft
        case .trailing: return .centerRight
        default:        return .centerCenter             // .center
        }
    }
}

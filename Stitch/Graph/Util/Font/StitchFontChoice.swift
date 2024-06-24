//
//  StitchFontChoice.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/22/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// Currently: just represents distinct `FontDesign` choices
extension StitchFontChoice {
    var asFontDesign: Font.Design {
        switch self {
        case .sf:
            return .default
        case .sfMono:
            return .monospaced
        case .sfRounded:
            return .rounded
        case .newYorkSerif:
            return .serif
        }
    }
}

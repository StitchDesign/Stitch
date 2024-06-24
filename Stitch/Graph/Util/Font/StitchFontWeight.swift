//
//  StitchFontWeight.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/22/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// Note: this enum is constructed with unique `font choice` + `font weight` combos so that we can get a single checkmark in the SwiftUI Picker for the single possible selected Stitch Font Choice.
// Using a single `.regular, .black, ...` etc. means that every submenu will have an active checkmark, i.e. a confusing UI.
extension StitchFontWeight: Identifiable {

    public var id: String {
        self.rawValue
    }

    var display: String {
        switch self {
        case .SF_regular, .SFMono_regular, .SFRounded_regular, .NewYorkSerif_regular:
            return "Regular"
        case .SF_black, .SFMono_black, .SFRounded_black, .NewYorkSerif_black:
            return "Black"
        case .SF_thin, .SFMono_thin, .SFRounded_thin, .NewYorkSerif_thin:
            return "Thin"
        case .SF_light, .SFMono_light, .SFRounded_light, .NewYorkSerif_light:
            return "Light"
        case .SF_ultraLight, .SFMono_ultraLight, .SFRounded_ultraLight, .NewYorkSerif_ultraLight:
            return "Ultra Light"
        case .SF_medium, .SFMono_medium, .SFRounded_medium, .NewYorkSerif_medium:
            return "Medium"
        case .SF_semibold, .SFMono_semibold, .SFRounded_semibold, .NewYorkSerif_semibold:
            return "Semibold"
        case .SF_bold, .SFMono_bold, .SFRounded_bold, .NewYorkSerif_bold:
            return "Bold"
        case .SF_heavy, .SFMono_heavy, .SFRounded_heavy, .NewYorkSerif_heavy:
            return "Heavy"
        }
    }

    var asFontWeight: Font.Weight {
        switch self {
        case .SF_regular, .SFMono_regular, .SFRounded_regular, .NewYorkSerif_regular:
            return .regular
        case .SF_black, .SFMono_black, .SFRounded_black, .NewYorkSerif_black:
            return .black
        case .SF_thin, .SFMono_thin, .SFRounded_thin, .NewYorkSerif_thin:
            return .thin
        case .SF_light, .SFMono_light, .SFRounded_light, .NewYorkSerif_light:
            return .light
        case .SF_ultraLight, .SFMono_ultraLight, .SFRounded_ultraLight, .NewYorkSerif_ultraLight:
            return .ultraLight
        case .SF_medium, .SFMono_medium, .SFRounded_medium, .NewYorkSerif_medium:
            return .medium
        case .SF_semibold, .SFMono_semibold, .SFRounded_semibold, .NewYorkSerif_semibold:
            return .semibold
        case .SF_bold, .SFMono_bold, .SFRounded_bold, .NewYorkSerif_bold:
            return .bold
        case .SF_heavy, .SFMono_heavy, .SFRounded_heavy, .NewYorkSerif_heavy:
            return .heavy
        }
    }

    var isForSF: Bool {
        switch self {
        case .SF_regular,
             .SF_black,
             .SF_thin,
             .SF_light,
             .SF_ultraLight,
             .SF_medium,
             .SF_semibold,
             .SF_bold,
             .SF_heavy:
            return true
        default:
            return false
        }
    }

    var isForSFMono: Bool {
        switch self {
        case .SFMono_regular,
             .SFMono_black,
             .SFMono_thin,
             .SFMono_light,
             .SFMono_ultraLight,
             .SFMono_medium,
             .SFMono_semibold,
             .SFMono_bold,
             .SFMono_heavy:
            return true
        default:
            return false
        }
    }

    var isForSFRounded: Bool {
        switch self {
        case .SFRounded_regular,
             .SFRounded_black,
             .SFRounded_thin,
             .SFRounded_light,
             .SFRounded_ultraLight,
             .SFRounded_medium,
             .SFRounded_semibold,
             .SFRounded_bold,
             .SFRounded_heavy:
            return true
        default:
            return false
        }
    }

    var isForNewYorkSerif: Bool {
        switch self {
        case .NewYorkSerif_regular,
             .NewYorkSerif_black,
             .NewYorkSerif_thin,
             .NewYorkSerif_light,
             .NewYorkSerif_ultraLight,
             .NewYorkSerif_medium,
             .NewYorkSerif_semibold,
             .NewYorkSerif_bold,
             .NewYorkSerif_heavy:
            return true
        default:
            return false
        }
    }
}

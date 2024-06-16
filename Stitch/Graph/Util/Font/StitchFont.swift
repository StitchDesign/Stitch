//
//  StitchFont.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/22/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// the value that lives in the input's PortValue and which is passed down to view models etc.
extension StitchFont {
    var display: String {
        self.fontChoice.rawValue + " " + self.fontWeight.display
    }

    // default input value
    static let defaultStitchFont: Self = .init(fontChoice: .sf,
                                               fontWeight: .SF_regular)
}

let defaultStitchFontPortValue = PortValue.textFont(.defaultStitchFont)

extension StitchFont {
    init(_ fontChoice: StitchFontChoice,
         _ fontWeight: StitchFontWeight) {
        self.init(fontChoice: fontChoice,
                  fontWeight: fontWeight)
    }
}

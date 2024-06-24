//
//  IconName.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/12/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// We often generate a UIImage from an SF Symbol
// or custom icon SVG.
enum IconName: Equatable {
    case sfSymbol(String),
         svgIcon(String)

    var name: String {
        switch self {
        case .sfSymbol(let string):
            return string
        case .svgIcon(let string):
            return string
        }
    }
}

extension IconName {
    var image: Image {
        switch self {
        case .sfSymbol(let string):
            return Image(systemName: string)
        case .svgIcon(let string):
            return Image(uiImage: UIImage(named: string)!)
        }
    }
}

let TOP_BAR_IMAGE_BUTTON_FOREGROUND_COLOR: Color = Color(.topBarImageButtonForeground)

//
//  PulseColor.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let FLASHED_PORT_COLOR: Color = Color.yellow.opacity(1.0)

enum PulseColor: Equatable {
    case active, // flashing
         inactive // not flashing

    var color: Color {
        switch self {
        case .active:
            return FLASHED_PORT_COLOR
        case .inactive:
            return PORT_COLOR
        }
    }
}

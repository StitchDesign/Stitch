//
//  StitchAICodableTypes.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/7/25.
//

import SwiftUI
import StitchSchemaKit

/**
 Saves JSON-friendly versions of data structures saved in `PortValue`.
 */

struct StitchAIPosition: Codable {
    var x: Double
    var y: Double
}


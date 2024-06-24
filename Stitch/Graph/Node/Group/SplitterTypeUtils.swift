//
//  SplitterType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/21/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension SplitterType {
    var isGroupSplitter: Bool {
        switch self {
        case .inline:
            return false
        case .input, .output:
            return true
        }
    }
}

//
//  CommentExpansionBox.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/6/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension CommentExpansionBox {
    static let defaultExpansionBox = CommentExpansionBox(
        expansionDirection: nil,
        size: .init(width: 200.magnitude + 60,
                    height: 200.magnitude + 60),
        startPoint: .init(x: 200, y: 200),
        endPoint: .init(x: 460, y: 460))
}

//
//  NodeBounds.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/24.
//

import Foundation

struct NodeBounds: Equatable, Hashable, Codable {
    // bounds used for creation of comment box
    var localBounds: CGRect = .zero

    // bounds used for node selection cursor
    var graphBaseViewBounds: CGRect = .zero
}

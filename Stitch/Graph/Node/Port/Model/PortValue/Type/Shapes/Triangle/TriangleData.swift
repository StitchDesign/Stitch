//
//  TrianglePoints.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/2/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension TriangleData {
    static let defaultTriangleP1: CGPoint = .zero
    static let defaultTriangleP2: CGPoint = .init(x: 0, y: -100)
    static let defaultTriangleP3: CGPoint = .init(x: 100, y: 0)

    static let defaultTriangle = TriangleData(
        p1: Self.defaultTriangleP1,
        p2: Self.defaultTriangleP2,
        p3: Self.defaultTriangleP3)
}

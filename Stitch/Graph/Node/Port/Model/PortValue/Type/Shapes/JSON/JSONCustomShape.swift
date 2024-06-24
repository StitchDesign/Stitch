//
//  JSONCustomShape.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/20/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct JSONCustomShape: Shape {
    let jsonCommands: JSONShapeCommands

    func path(in rect: CGRect) -> Path {

        var path = Path()

        for command in jsonCommands {
            switch command {
            // TODO: is this really handled properly?
            case .closePath:
                path.closeSubpath()
            case .moveTo(let cgPoint):
                path.move(to: cgPoint)
            case .lineTo(let cgPoint):
                path.addLine(to: cgPoint)
            case .curveTo(let curveData):
                path.addCurve(to: curveData.point,
                              control1: curveData.controlPoint1,
                              control2: curveData.controlPoint2)
            }
        }

        return path
    }
}

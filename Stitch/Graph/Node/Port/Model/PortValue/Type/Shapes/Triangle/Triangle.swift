//
//  Triangle.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/8/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Drawing an arc and a triangle; arc gotcha: https://www.hackingwithswift.com/books/ios-swiftui/paths-vs-shapes-in-swiftui

// Polygons and stars: https://blog.techchee.com/how-to-create-custom-shapes-in-swiftui/

// Official SwiftUI tutorial: https://developer.apple.com/tutorials/swiftui/drawing-paths-and-shapes

// https://www.hackingwithswift.com/books/ios-swiftui/adding-strokeborder-support-with-insettableshape
struct Triangle: Shape {

    let p1: CGPoint
    let p2: CGPoint
    let p3: CGPoint

    var points: CGPoints {
        [p1, p2, p3]
    }

    // SwiftUI Shape protocol requires the `in rect: CGRect` signature
    // This function seems to
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        path.addLine(to: p1)

        return path
    }
}

struct IsoscelesTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

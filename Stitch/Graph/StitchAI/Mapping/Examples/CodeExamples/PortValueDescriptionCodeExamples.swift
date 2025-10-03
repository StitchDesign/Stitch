//
//  PortValueDescriptionCodeExamples.swift
//  Stitch
//
//  Created by Claude on 8/1/25.
//

import Foundation

/// Examples showing SwiftUI code using PortValueDescription format
/// These demonstrate how arguments can be wrapped in PortValueDescription
/// for the visual programming system
struct PortValueDescriptionCodeExamples {

    static let rectangleWithDragGestureMathExpressions = MappingCodeExample(
        title: "Rectangle with Math Expressions in Drag Gesture",
        code: """
struct ContentView: View {

    var body: some View {
        Rectangle()
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        rectanglePosition = [PortValueDescription(value: ["x": value.location.x - 196.5, "y": value.location.y - 426], value_type: "position")]
                    }
            )
    }
}
"""
    )

    static let ellipseWithStaticMathExpressions = MappingCodeExample(
        title: "Ellipse with Static Math Expressions",
        code: """
Ellipse()
    .offset([PortValueDescription(value: ["x": 500 - 196.5, "y": 500 - 426], value_type: "position")])
"""
    )

    static let rectangleWithColorPVD = MappingCodeExample(
        title: "Rectangle with PortValueDescription color",
        code: """
Rectangle()
    .fill([PortValueDescription(value: "#00FF00FF", value_type: "color")])
"""
    )
    
    static let ellipseWithSizePVD = MappingCodeExample(
        title: "Ellipse with PortValueDescription size",
        code: """
Ellipse()
    .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])
"""
    )
    
    static let textWithOpacityPVD = MappingCodeExample(
        title: "Text with PortValueDescription opacity",
        code: """
Text("Hello World")
    .opacity([PortValueDescription(value: 0.5, value_type: "number")])
"""
    )
    
    static let rectangleWithBlurPVD = MappingCodeExample(
        title: "Rectangle with PortValueDescription blur",
        code: """
Rectangle()
    .blur(radius: [PortValueDescription(value: 5.0, value_type: "number")])
    .fill([PortValueDescription(value: "#FF0000FF", value_type: "color")])
"""
    )
    
    static let stackWithPortValueDescriptions = MappingCodeExample(
        title: "VStack with multiple PortValueDescriptions",
        code: """
VStack {
    Rectangle()
        .fill([PortValueDescription(value: "#FF0000FF", value_type: "color")])
        .frame([PortValueDescription(value: ["width":"100.0","height":"50.0"], value_type: "size")])
    
    Ellipse()
        .fill([PortValueDescription(value: "#0000FFFF", value_type: "color")])
        .opacity([PortValueDescription(value: 0.8, value_type: "number")])
}
"""
    )
    
    static let textWithFontSizePVD = MappingCodeExample(
        title: "Text with PortValueDescription font size",
        code: """
Text("love")
    .font([PortValueDescription(value_type: "number", value: 36)])
"""
    )
}

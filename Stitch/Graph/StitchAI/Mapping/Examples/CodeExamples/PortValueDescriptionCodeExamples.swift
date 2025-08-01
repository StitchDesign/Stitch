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
}

//
//  OverlayExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/27/25.
//

import Foundation
import SwiftUI

struct OverlayCodeExamples {
    
    static let simpleOverlayFunctionCall = MappingCodeExample(
        title: "Simple Overlay (Function Call)",
        code: """
        Rectangle()
            .overlay(Ellipse())
        """
    )
    
    static let simpleOverlayClosure = MappingCodeExample(
        title: "Simple Overlay (Closure)",
        code: """
        Rectangle()
            .overlay {
                Ellipse()
            }
        """
    )
    
    static let multipleChildrenOverlay = MappingCodeExample(
        title: "Multiple Children in Overlay",
        code: """
        Rectangle()
            .overlay {
                Ellipse()
                Text("Text")
            }
        """
    )
    
    static let vstackOverlay = MappingCodeExample(
        title: "VStack in Overlay",
        code: """
        Rectangle()
            .overlay {
                VStack {
                    Ellipse()
                    Text("Text")
                }
            }
        """
    )
    
    static let complexOverlayWithModifiers = MappingCodeExample(
        title: "Complex Overlay with Modifiers",
        code: """
        Rectangle()
            .fill(.blue)
            .overlay {
                Circle()
                    .fill(.red)
                    .frame(width: 50, height: 50)
            }
            .padding()
        """
    )
    
    static let nestedOverlay = MappingCodeExample(
        title: "Nested Overlay",
        code: """
        Rectangle()
            .overlay {
                Rectangle()
                    .fill(.green)
                    .overlay {
                        Text("Nested")
                    }
            }
        """
    )
    
    // New overlay examples with modifiers - testing the fix for Text with .foregroundColor
    static let overlayTextWithForegroundColor = MappingCodeExample(
        title: "Overlay Text with ForegroundColor",
        code: """
        Ellipse()
            .overlay(
                Text("A")
                    .foregroundColor(.blue)
            )
        """
    )
    
    static let overlayVStackWithModifiers = MappingCodeExample(
        title: "Overlay VStack with Frame Modifier",
        code: """
        Ellipse()
            .overlay(
                VStack {
                    Text("A")
                        .foregroundColor(.blue)
                }.frame(width: 100, height: 200)
            )
        """
    )
    
    static let overlayTextWithPortValueDescription = MappingCodeExample(
        title: "Overlay Text with PortValueDescription",
        code: """
        Ellipse()
            .overlay(
                Text([PortValueDescription(value: "*", value_type: "string")])
                    .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
            )
        """
    )
    
    static let overlayWithFrameModifier = MappingCodeExample(
        title: "Overlay with Frame on Base View",
        code: """
        Ellipse()
            .overlay(
                Text("A")
                    .foregroundColor(.blue)
            )
            .frame(width: 100, height: 200)
        """
    )
    
    static let overlayWithClosureSyntax = MappingCodeExample(
        title: "Overlay with Closure Syntax",
        code: """
        Ellipse()
            .overlay {
                Text("A")
                    .foregroundColor(.blue)
            }
            .frame(width: 100, height: 200)
        """
    )
}

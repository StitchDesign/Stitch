//
//  BackgroundExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/27/25.
//

import Foundation

struct BackgroundCodeExamples {
    
    static let simpleBackgroundFunctionCall = MappingCodeExample(
        title: "Simple Background - Function Call",
        code: """
Rectangle()
    .background(Ellipse())
"""
    )
    
    static let simpleBackgroundClosure = MappingCodeExample(
        title: "Simple Background - Closure",
        code: """
Rectangle()
    .background {
        Ellipse()
    }
"""
    )
    
    static let multipleChildrenBackground = MappingCodeExample(
        title: "Background with Multiple Children",
        code: """
Rectangle()
    .background {
        Ellipse()
        Text("Background Text")
    }
"""
    )
    
    static let vstackBackground = MappingCodeExample(
        title: "VStack with Background",
        code: """
VStack {
    Text("Main Content")
    Rectangle()
}
.background {
    Color.blue
    Circle()
}
"""
    )
    
    static let complexBackgroundWithModifiers = MappingCodeExample(
        title: "Complex Background with Modifiers",
        code: """
Text("Foreground")
    .padding()
    .background {
        Rectangle()
            .fill(Color.red)
            .opacity(0.5)
        Ellipse()
            .stroke(Color.blue)
    }
    .frame(width: 200, height: 100)
"""
    )
    
    static let nestedBackground = MappingCodeExample(
        title: "Nested Background",
        code: """
Rectangle()
    .background {
        Circle()
            .background {
                Color.yellow
            }
    }
"""
    )
    
    // New background examples with modifiers - testing the fix for Text with .foregroundColor
    static let backgroundTextWithForegroundColor = MappingCodeExample(
        title: "Background Text with ForegroundColor",
        code: """
        Ellipse()
            .background(
                Text("A")
                    .foregroundColor(.blue)
            )
        """
    )
    
    static let backgroundVStackWithModifiers = MappingCodeExample(
        title: "Background VStack with Frame Modifier",
        code: """
        Ellipse()
            .background(
                VStack {
                    Text("A")
                        .foregroundColor(.blue)
                }.frame(width: 100, height: 200)
            )
        """
    )
}
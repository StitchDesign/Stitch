//
//  AICodeGenaSystemPromptGenerator.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/25/25.
//
import SwiftUI

extension StitchAIManager {
    static func aiCodeGenSystemPromptGenerator(requestType: StitchAIRequestBuilder_V0.StitchAIRequestType, previewWindowSize: CGSize, previewWindowBackgroundColor: Color) throws -> String {
        let supportedViewModifiers = SyntaxViewModifierName.allCases
            .filter {
                do {
                    // allow nil cases
                    let _ = try $0.deriveLayerInputPort()
                    return true
                } catch {
                    return false
                }
            }
            .map(\.rawValue)
        
        return """

You are an excellent Swift and SwiftUI developer.

Return ONLY CODE and NOTHING ELSE. NO COMMENTS, NO EXPLANATIONS, etc.

Always return all code in a `struct ContentView: View`.

USE PortValueDescription when possible.
"""
    }
}

/*
 DO NOT use these SwiftUI views:
 * `Button`
 * `LazyVGrid`
 * `GeometryReader`
 * `ForEach`

 DO NOT use these SwiftUI view modifiers:
 * `.onAppear`
 * `.clipShape`
 * `.minimumScaleFactor`
 * `.task`

 DO NOT USE Swift tuples or custom structs or custom views or custom view modifiers.

 USE PortValueDescription when possible.
 */

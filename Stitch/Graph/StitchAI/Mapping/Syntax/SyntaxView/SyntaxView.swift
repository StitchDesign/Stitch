//
//  ViewNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation

// fka `ViewNode`
struct SyntaxView: Equatable {
        
    // representation of a SwiftUI View
    // e.g. `Text`, `Rectangle`, `Image`
    var name: SyntaxViewName  // strongly-typed SwiftUI view kind
    
    // arguments to the View's construct,
    // e.g. ("systemName", "star.fill") for Image(systemName: "star.fill")
    var constructorArguments: ViewConstructorType?
    
    // representation of SwiftUI view modifiers, including name and arguments
    // e.g. `.padding()`, `.opacity(0.5)`, `.frame(width: 100, height: 200)`
    var modifiers: [SyntaxViewModifier]
    
    var children: [SyntaxView]
    
    var id: UUID  // Unique identifier for the node
}

enum ViewConstructorType: Equatable, Sendable, Encodable {
    case trackedConstructor(ViewConstructor)
    case other([SyntaxViewArgumentData])
}

extension ViewConstructorType {
    var defaultArgs: [SyntaxViewArgumentData]? {
        switch self {
        case .trackedConstructor:
            return nil
        case .other(let array):
            return array
        }
    }
}

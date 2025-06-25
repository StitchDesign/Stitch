//
//  ViewNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation

// fka `ViewNode`
struct SyntaxView: Equatable, Hashable {
    
    // representation of a SwiftUI View
    // e.g. `Text`, `Rectangle`, `Image`
    var name: ViewKind  // strongly-typed SwiftUI view kind
    
    // arguments to the View's construct,
    // e.g. ("systemName", "star.fill") for Image(systemName: "star.fill")
    var constructorArguments: [ConstructorArgument]
    
    // representation of SwiftUI view modifiers, including name and arguments
    // e.g. `.padding()`, `.opacity(0.5)`, `.frame(width: 100, height: 200)`
    var modifiers: [Modifier]
    
    var children: [SyntaxView]
    
    // TODO: use UUID
    var id: String  // Unique identifier for the node
}

//
//  ConstructorArgument.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation

// TODO: a way to represent the type of the SwiftUI View constructor arg ?
// Note: this can only really properly be resolved into a LayerInputPort with the help of the known layer
enum SyntaxConstructorArgumentLabel: String, Equatable, Hashable {
    
    
    /*
     argument without a label
     - e.g. SwiftUI Text: `Text("love")`
     - e.g. SwiftUI ScrollView: `ScrollView(.horizontal) { ... }` or `ScrollView([.horizontal, .vertical]) { ... }`
     
     Note: SwiftUI views that do not take arguments at all (e.g. `Rectangle()`) will not actually have constructor-args
     
     https://developer.apple.com/documentation/swiftui/text#Creating-a-text-view
     */
//    case noLabel = ""
    
    // case verbatim = "verbatim"
    
    // SwiftUI Image
    // https://developer.apple.com/documentation/swiftui/image#Creating-an-image
    case systemName = "systemName"
    
    case cornerRadius = "cornerRadius"
    
    case spacing = "spacing"
}

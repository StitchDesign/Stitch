//
//  ConstructorArgument.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation


struct SyntaxViewConstructorArgument: Equatable, Hashable {
    
    /*
     TODO: combine labels + values ? how to elegantly handle difference between no args like `Rectangle`, un-labeled args like `Text("love")` and labeled args like `Image(systemName:)`
     
     Note: `Rectangle()` actually takes NO constructor arguments
     
     */
    let label: SyntaxConstructorArgumentLabel
    
    // Note: some SwiftUI view modifiers "do not take an argument" (e.g. `.padding()`; though this is technically just defaulting to a default argument), BUT EVERY CONSTRUCTOR FOR A SWIFTUI VIEW TAKES AN ARGUMENT, so this is non-optional
    let value: String
    
    let syntaxKind: SyntaxArgumentKind // literal vs declared var vs expression
}

// TODO: a way to represent the type of the SwiftUI View constructor arg ?
// Note: this can only really properly be resolved into a LayerInputPort with the help of the known layer
enum SyntaxConstructorArgumentLabel: String, Equatable, Hashable {
    
    
    // argument without a label, e.g. SwiftUI Text: `Text("love")`;
    // Note: SwiftUI views that do not take arguments at all (e.g. `Rectangle()`) will not actually have constructor-args
    // https://developer.apple.com/documentation/swiftui/text#Creating-a-text-view
    case noLabel = ""
    
    // case verbatim = "verbatim"
    
    // SwiftUI Image
    // https://developer.apple.com/documentation/swiftui/image#Creating-an-image
    case systemName = "systemName"
    
    // HStack, VStack, ZStack
    // case alignment = "alignment"
    // case spacing = "spacing"
        
    // Use `Argument` to capture unsupported constructors on SwiftUI Views,
    // e.g. `Text(Date, style: Text.DateStyle)`
    
    // Rather than keeping around which argument was unsupported, we should log at the given site etc. and react
    case unsupported //(Argument)
}

extension SyntaxConstructorArgumentLabel {
    static func from(_ string: String?) -> SyntaxConstructorArgumentLabel? {
        switch string {
        case .none:
            return .noLabel
        case .some(let x):
            return Self(rawValue: x)
        }
    }
}


//// TODO: have ChatGPT crawl SwiftUI documentation for constructors (usually the "Creating a ..." section) and define more `ConstructorArgument` cases
//
//// https://developer.apple.com/documentation/swiftui/hstack#Creating-a-stack
//struct HStackConstructorArgument: Equatable, Hashable {
//    let alignment: String // VerticalAlignment
//    let spacing: CGFloat?
//    let content: SyntaxView
//}
//
//// https://developer.apple.com/documentation/swiftui/vstack#Creating-a-stack
//struct VStackConstructorArgument: Equatable, Hashable {
//    let alignment: String // HorizontalAlignment
//    let spacing: CGFloat?
//    let content: SyntaxView
//}
//

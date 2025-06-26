//
//  StitchSyntaxExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/23/25.
//

import Foundation


// MARK: EXAMPLES

// Example for complex modifiers with multiple parameters
// SwiftUI code:
// Rectangle()
//     .frame(width: 200, height: 100, alignment: .center)
let complexModifierExample = SyntaxView(
    name: .init(from: "Rectangle")!,
    constructorArguments: [],
    modifiers: [
        SyntaxViewModifier(
            name: .frame,
            arguments: [
                SyntaxViewModifierArgument(label: .width,  value: "200", syntaxKind: .literal(.integer)),
                SyntaxViewModifierArgument(label: .height, value: "100", syntaxKind: .literal(.integer)),
                SyntaxViewModifierArgument(label: .alignment, value: ".center", syntaxKind: .variable(.memberAccess))
            ]
        )
    ],
    children: [],
    id: UUID()
)


// SwiftUI code:
// ZStack {
//     Rectangle().fill(Color.blue)
//     Rectangle().fill(Color.green)
// }
let example1 = SyntaxView(
    name: .init(from: "ZStack")!,
    constructorArguments: [],
    modifiers: [],
    children: [
        SyntaxView(
            name: .init(from: "Rectangle")!,
            constructorArguments: [],
            modifiers: [
                SyntaxViewModifier(
                    name: .fill,
                    arguments: [SyntaxViewModifierArgument(label: .noLabel, value: "Color.blue", syntaxKind: .variable(.memberAccess))]
                )
            ],
            children: [],
            id: UUID()
        ),
        SyntaxView(
            name: .init(from: "Rectangle")!,
            constructorArguments: [],
            modifiers: [
                SyntaxViewModifier(
                    name: .fill,
                    arguments: [SyntaxViewModifierArgument(label: .noLabel, value: "Color.green", syntaxKind: .variable(.memberAccess))]
                )
            ],
            children: [],
            id: UUID()
        )
    ],
    id: UUID()
)


// SwiftUI code:
// Text("salut")
let example2 = SyntaxView(
    name: .init(from: "Text")!,
    constructorArguments: [
        SyntaxViewConstructorArgument(label: .noLabel,
                            value: "\"salut\"",
                            syntaxKind: .literal(.string))
    ],
    modifiers: [],
    children: [],
    id: UUID()
)

// SwiftUI code:
// Text("salut").foregroundColor(Color.yellow).padding()
let example3 = SyntaxView(
    name: .init(from: "Text")!,
    constructorArguments: [
        SyntaxViewConstructorArgument(label: .noLabel,
                            value: "\"salut\"",
                            syntaxKind: .literal(.string))
        
    ],
    modifiers: [
        SyntaxViewModifier(
            name: .foregroundColor,
            arguments: [SyntaxViewModifierArgument(label: .noLabel, value: "Color.yellow", syntaxKind: .variable(.memberAccess))]
        ),
        SyntaxViewModifier(
            name: .padding,
            arguments: [SyntaxViewModifierArgument(label: .noLabel, value: "", syntaxKind: .literal(.unknown))]
        )
    ],
    children: [],
    id: UUID()
)


// SwiftUI code:
// ZStack {
//     Rectangle().fill(Color.blue)
//     VStack {
//        Rectangle().fill(Color.green)
//        Rectangle().fill(Color.red)
//     }
// }
let example4 = SyntaxView(
    name: .init(from: "ZStack")!,
    constructorArguments: [],
    modifiers: [],
    children: [
        SyntaxView(
            name: .init(from: "Rectangle")!,
            constructorArguments: [],
            modifiers: [
                SyntaxViewModifier(
                    name: .fill,
                    arguments: [SyntaxViewModifierArgument(label: .noLabel, value: "Color.blue", syntaxKind: .variable(.memberAccess))]
                )
            ],
            children: [],
            id: UUID()
        ),
        SyntaxView(
            name: .init(from: "VStack")!,
            constructorArguments: [],
            modifiers: [],
            children: [
                SyntaxView(
                    name: .init(from: "Rectangle")!,
                    constructorArguments: [],
                    modifiers: [
                        SyntaxViewModifier(
                            name: .fill,
                            arguments: [SyntaxViewModifierArgument(label: .noLabel, value: "Color.green", syntaxKind: .variable(.memberAccess))]
                        )
                    ],
                    children: [],
                    id: UUID()
                ),
                SyntaxView(
                    name: .init(from: "Rectangle")!,
                    constructorArguments: [],
                    modifiers: [
                        SyntaxViewModifier(
                            name: .fill,
                            arguments: [SyntaxViewModifierArgument(label: .noLabel, value: "Color.red", syntaxKind: .variable(.memberAccess))]
                        )
                    ],
                    children: [],
                    id: UUID()
                )
            ],
            id: UUID()
        )
    ],
    id: UUID()
)

// SwiftUI code:
// Image(systemName: "star.fill")

let example5 = SyntaxView(
    name: .init(from: "Image")!,
    constructorArguments: [
        SyntaxViewConstructorArgument(label: .systemName,
                            value: "\"star.fill\"",
                            syntaxKind: .literal(.string))
    ],
    modifiers: [],
    children: [],
    id: UUID()
)



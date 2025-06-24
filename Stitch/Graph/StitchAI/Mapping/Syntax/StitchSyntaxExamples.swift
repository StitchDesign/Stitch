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
let complexModifierExample = ViewNode(
    name: .init(from: "Rectangle"),
    arguments: [],
    modifiers: [
        Modifier(
            kind: .frame,
            arguments: [
                Argument(label: "width",  value: "200", syntaxKind: .literal(.integer)),
                Argument(label: "height", value: "100", syntaxKind: .literal(.integer)),
                Argument(label: "alignment", value: ".center", syntaxKind: .variable(.memberAccess))
            ]
        )
    ],
    children: [],
    id: "rectangle6"
)


// SwiftUI code:
// ZStack {
//     Rectangle().fill(Color.blue)
//     Rectangle().fill(Color.green)
// }
let example1 = ViewNode(
    name: .init(from: "ZStack"),
    arguments: [],
    modifiers: [],
    children: [
        ViewNode(
            name: .init(from: "Rectangle"),
            arguments: [],
            modifiers: [
                Modifier(
                    kind: .fill,
                    arguments: [Argument(label: nil, value: "Color.blue", syntaxKind: .variable(.memberAccess))]
                )
            ],
            children: [],
            id: "rectangle1"
        ),
        ViewNode(
            name: .init(from: "Rectangle"),
            arguments: [],
            modifiers: [
                Modifier(
                    kind: .fill,
                    arguments: [Argument(label: nil, value: "Color.green", syntaxKind: .variable(.memberAccess))]
                )
            ],
            children: [],
            id: "rectangle2"
        )
    ],
    id: "zstack1"
)


// SwiftUI code:
// Text("salut")
let example2 = ViewNode(
    name: .init(from: "Text"),
    arguments: [
        ConstructorArgument(label: .text(.noLabel),
                            value: "\"salut\"",
                            syntaxKind: .literal(.string))
    ],
    modifiers: [],
    children: [],
    id: "text1"
)

// SwiftUI code:
// Text("salut").foregroundColor(Color.yellow).padding()
let example3 = ViewNode(
    name: .init(from: "Text"),
    arguments: [
        ConstructorArgument(label: .text(.noLabel),
                            value: "\"salut\"",
                            syntaxKind: .literal(.string))
        
    ],
    modifiers: [
        Modifier(
            kind: .foregroundColor,
            arguments: [Argument(label: nil, value: "Color.yellow", syntaxKind: .variable(.memberAccess))]
        ),
        Modifier(
            kind: .padding,
            arguments: [Argument(label: nil, value: "", syntaxKind: .literal(.unknown))]
        )
    ],
    children: [],
    id: "text2"
)


// SwiftUI code:
// ZStack {
//     Rectangle().fill(Color.blue)
//     VStack {
//        Rectangle().fill(Color.green)
//        Rectangle().fill(Color.red)
//     }
// }
let example4 = ViewNode(
    name: .init(from: "ZStack"),
    arguments: [],
    modifiers: [],
    children: [
        ViewNode(
            name: .init(from: "Rectangle"),
            arguments: [],
            modifiers: [
                Modifier(
                    kind: .fill,
                    arguments: [Argument(label: nil, value: "Color.blue", syntaxKind: .variable(.memberAccess))]
                )
            ],
            children: [],
            id: "rectangle3"
        ),
        ViewNode(
            name: .init(from: "VStack"),
            arguments: [],
            modifiers: [],
            children: [
                ViewNode(
                    name: .init(from: "Rectangle"),
                    arguments: [],
                    modifiers: [
                        Modifier(
                            kind: .fill,
                            arguments: [Argument(label: nil, value: "Color.green", syntaxKind: .variable(.memberAccess))]
                        )
                    ],
                    children: [],
                    id: "rectangle4"
                ),
                ViewNode(
                    name: .init(from: "Rectangle"),
                    arguments: [],
                    modifiers: [
                        Modifier(
                            kind: .fill,
                            arguments: [Argument(label: nil, value: "Color.red", syntaxKind: .variable(.memberAccess))]
                        )
                    ],
                    children: [],
                    id: "rectangle5"
                )
            ],
            id: "vstack1"
        )
    ],
    id: "zstack2"
)

// SwiftUI code:
// Image(systemName: "star.fill")

let example5 = ViewNode(
    name: .init(from: "Image"),
    arguments: [
        ConstructorArgument(label: .image(.systemName), //"systemName",
                            value: "\"star.fill\"",
                            syntaxKind: .literal(.string))
    ],
    modifiers: [],
    children: [],
    id: "image1"
)



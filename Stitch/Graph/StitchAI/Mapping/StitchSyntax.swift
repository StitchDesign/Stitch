//
//  StitchSyntax.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/25.
//

import Foundation
import SwiftUI
import SwiftSyntax
import SwiftParser


struct ViewNode {
    var name: String // the name of the SwiftUI View
    var arguments: [(label: String?, value: String)] // arguments for the View, e.g. ("systemName", "star.fill") for Image(systemName: "star.fill")
    var modifiers: [Modifier] // modifiers for the View, e.g. .padding()
    var children: [ViewNode]
    var id: String  // Unique identifier for the node
}

struct Modifier {
    let name: String
    let value: String
    var arguments: [(label: String?, value: String)]  // For more complex modifiers
}


// MARK: EXAMPLES

// Example for complex modifiers with multiple parameters
// SwiftUI code:
// Rectangle()
//     .frame(width: 200, height: 100, alignment: .center)

let complexModifierExample = ViewNode(
    name: "Rectangle",
    arguments: [],
    modifiers: [
        Modifier(
            name: "frame",
            value: "",
            arguments: [
                (label: "width", value: "200"),
                (label: "height", value: "100"),
                (label: "alignment", value: ".center")
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
    name: "ZStack",
    arguments: [],
    modifiers: [],
    children: [
        ViewNode(
            name: "Rectangle",
            arguments: [],
            modifiers: [
                Modifier(
                    name: "fill",
                    value: "Color.blue",
                    arguments: []
                )
            ],
            children: [],
            id: "rectangle1"
        ),
        ViewNode(
            name: "Rectangle",
            arguments: [],
            modifiers: [
                Modifier(
                    name: "fill",
                    value: "Color.green",
                    arguments: []
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
    name: "Text",
    arguments: [(label: nil, value: "\"salut\"")],
    modifiers: [],
    children: [],
    id: "text1"
)

// SwiftUI code:
// Text("salut").foregroundColor(Color.yellow).padding()

let example3 = ViewNode(
    name: "Text",
    arguments: [(label: nil, value: "\"salut\"")],
    modifiers: [
        Modifier(
            name: "foregroundColor",
            value: "Color.yellow",
            arguments: []
        ),
        Modifier(
            name: "padding",
            value: "",
            arguments: []
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
    name: "ZStack",
    arguments: [],
    modifiers: [],
    children: [
        ViewNode(
            name: "Rectangle",
            arguments: [],
            modifiers: [
                Modifier(
                    name: "fill",
                    value: "Color.blue",
                    arguments: []
                )
            ],
            children: [],
            id: "rectangle3"
        ),
        ViewNode(
            name: "VStack",
            arguments: [],
            modifiers: [],
            children: [
                ViewNode(
                    name: "Rectangle",
                    arguments: [],
                    modifiers: [
                        Modifier(
                            name: "fill",
                            value: "Color.green",
                            arguments: []
                        )
                    ],
                    children: [],
                    id: "rectangle4"
                ),
                ViewNode(
                    name: "Rectangle",
                    arguments: [],
                    modifiers: [
                        Modifier(
                            name: "fill",
                            value: "Color.red",
                            arguments: []
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
    name: "Image",
    arguments: [(label: "systemName", value: "\"star.fill\"")],
    modifiers: [],
    children: [],
    id: "image1"
)


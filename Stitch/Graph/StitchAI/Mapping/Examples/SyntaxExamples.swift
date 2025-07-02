//
//  SyntaxExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/27/25.
//

import Foundation

extension MappingExamples {
    // MARK: EXAMPLES

    // Example for complex modifiers with multiple parameters
    // SwiftUI code:
    // Rectangle()
    //     .frame(width: 200, height: 100, alignment: .center)
    static let complexModifierExample = SyntaxView(
        name: .rectangle,
        constructorArguments: [],
        modifiers: [
            SyntaxViewModifier(
                name: .frame,
                arguments: [
                    SyntaxViewModifierArgument(
                        label: .width,
                        value: .simple(SyntaxViewModifierArgumentData(value: "200", syntaxKind: .literal(.integer)))
                    ),
                    SyntaxViewModifierArgument(
                        label: .height,
                        value: .simple(SyntaxViewModifierArgumentData(value: "100", syntaxKind: .literal(.integer)))
                    ),
                    SyntaxViewModifierArgument(
                        label: .alignment,
                        value: .simple(SyntaxViewModifierArgumentData(value: ".center", syntaxKind: .variable(.memberAccess)))
                    )
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
    static let example1 = SyntaxView(
        name: .zStack,
        constructorArguments: [],
        modifiers: [],
        children: [
            SyntaxView(
                name: .rectangle,
                constructorArguments: [],
                modifiers: [
                    SyntaxViewModifier(
                        name: .fill,
                        arguments: [
                            SyntaxViewModifierArgument(
                                label: .noLabel,
                                value: .simple(SyntaxViewModifierArgumentData(
                                    value: "Color.blue",
                                    syntaxKind: .variable(.memberAccess)
                                ))
                            )
                        ]
                    )
                ],
                children: [],
                id: UUID()
            ),
            SyntaxView(
                name: .rectangle,
                constructorArguments: [],
                modifiers: [
                    SyntaxViewModifier(
                        name: .fill,
                        arguments: [
                            SyntaxViewModifierArgument(
                                label: .noLabel,
                                value: .simple(SyntaxViewModifierArgumentData(
                                    value: "Color.green",
                                    syntaxKind: .variable(.memberAccess)
                                ))
                            )
                        ]
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
    static let example2 = SyntaxView(
        name: .text,
        constructorArguments: [
            SyntaxViewConstructorArgument(
                label: .noLabel,
                values: [
                    SyntaxViewConstructorArgumentValue(value: "\"salut\"",
                                                       syntaxKind: .literal(.string))
                ]
            )
        ],
        modifiers: [],
        children: [],
        id: UUID()
    )

    // SwiftUI code:
    // Text("salut").foregroundColor(Color.yellow).padding()
    static let example3 = SyntaxView(
        name: .text,
        constructorArguments: [
            SyntaxViewConstructorArgument(
                label: .noLabel,
                values: [
                    SyntaxViewConstructorArgumentValue(value: "\"salut\"",
                                                       syntaxKind: .literal(.string))
                ]
            )
            
        ],
        modifiers: [
            SyntaxViewModifier(
                name: .foregroundColor,
                arguments: [
                    SyntaxViewModifierArgument(
                        label: .noLabel,
                        value: .simple(SyntaxViewModifierArgumentData(
                            value: "Color.yellow",
                            syntaxKind: .variable(.memberAccess)
                        ))
                    )
                ]
            ),
            SyntaxViewModifier(
                name: .padding,
                arguments: [
                    SyntaxViewModifierArgument(
                        label: .noLabel,
                        value: .simple(SyntaxViewModifierArgumentData(
                            value: "",
                            syntaxKind: .literal(.unknown)
                        ))
                    )
                ]
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
    static let example4 = SyntaxView(
        name: .zStack,
        constructorArguments: [],
        modifiers: [],
        children: [
            SyntaxView(
                name: .rectangle,
                constructorArguments: [],
                modifiers: [
                    SyntaxViewModifier(
                        name: .fill,
                        arguments: [
                            SyntaxViewModifierArgument(
                                label: .noLabel,
                                value: .simple(SyntaxViewModifierArgumentData(
                                    value: "Color.blue",
                                    syntaxKind: .variable(.memberAccess)
                                ))
                            )
                        ]
                    )
                ],
                children: [],
                id: UUID()
            ),
            SyntaxView(
                name: .vStack,
                constructorArguments: [],
                modifiers: [],
                children: [
                    SyntaxView(
                        name: .rectangle,
                        constructorArguments: [],
                        modifiers: [
                            SyntaxViewModifier(
                                name: .fill,
                                arguments: [
                                    SyntaxViewModifierArgument(
                                        label: .noLabel,
                                        value: .simple(SyntaxViewModifierArgumentData(
                                            value: "Color.green",
                                            syntaxKind: .variable(.memberAccess)
                                        ))
                                    )
                                ]
                            )
                        ],
                        children: [],
                        id: UUID()
                    ),
                    SyntaxView(
                        name: .rectangle,
                        constructorArguments: [],
                        modifiers: [
                            SyntaxViewModifier(
                                name: .fill,
                                arguments: [
                                    SyntaxViewModifierArgument(
                                        label: .noLabel,
                                        value: .simple(SyntaxViewModifierArgumentData(
                                            value: "Color.red",
                                            syntaxKind: .variable(.memberAccess)
                                        ))
                                    )
                                ]
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

    static let example5 = SyntaxView(
        name: .rectangle,
        constructorArguments: [
            SyntaxViewConstructorArgument(
                label: .systemName,
                values: [
                    SyntaxViewConstructorArgumentValue(value: "\"star.fill\"",
                                                       syntaxKind: .literal(.string))
                ]
            )
        ],
        modifiers: [],
        children: [],
        id: UUID()
    )



}

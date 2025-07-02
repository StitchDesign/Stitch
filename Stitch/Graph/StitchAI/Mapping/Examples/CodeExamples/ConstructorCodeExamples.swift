//
//  ConstructorCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/2/25.
//

import Foundation

struct ConstructorCodeExamples {

    static let roundedRectangle = MappingCodeExample(
        title: "RoundedRectangle",
        code: "RoundedRectangle(cornerRadius: 25)"
    )

    static let text = MappingCodeExample(
        title: "Text",
        code: #"Text("salut")"#
    )

    static let text_with_color = MappingCodeExample(
        title: "Text with color",
        code: #"Text("salut").foregroundColor(Color.yellow).padding()"#
    )

    static let image = MappingCodeExample(
        title: "Image",
        code: #"Image(systemName: "star.fill")"#
    )
}

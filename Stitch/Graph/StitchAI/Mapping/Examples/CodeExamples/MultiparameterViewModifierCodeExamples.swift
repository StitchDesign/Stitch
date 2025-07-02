//
//  MultiparameterViewModifierCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/2/25.
//

import Foundation


struct MultiparameterViewModifierCodeExamples {
    static let position = MappingCodeExample(
        title: "Position",
        code: """
        Rectangle()
            .position(x: 200, y: 200)
        """
    )

    static let offset = MappingCodeExample(
        title: "Offset",
        code: """
        Rectangle()
            .offset(x: 200, y: 200)
        """
    )

    static let frame = MappingCodeExample(
        title: "Frame",
        code: """
        Rectangle()
            .frame(width: 200, height: 100)
        """
    )
}

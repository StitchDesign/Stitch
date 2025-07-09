//
//  StackCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/2/25.
//

import Foundation


struct StackCodeExamples {
    static let vstack = MappingCodeExample(
        title: "VStack",
        code: """
        VStack(alignment: .center, spacing: 8) {
            Rectangle().fill(Color.blue)
        }
        """
    )

    static let zstack_rectangles = MappingCodeExample(
        title: "ZStack Rectangles",
        code: """
        ZStack {
            Rectangle().fill(Color.blue)
            Rectangle().fill(Color.green)
        }
        """
    )

    static let zstack_with_modifier = MappingCodeExample(
        title: "ZStack with modifier",
        code: """
        ZStack {
            Rectangle()
               .fill(Color.blue)
        }.scaleEffect(2)
        """
    )

    static let nested = MappingCodeExample(
        title: "Nested",
        code: """
        ZStack {
            Rectangle().fill(Color.blue)
            VStack {
                Rectangle().fill(Color.green)
                Rectangle().fill(Color.red)
            }
        }
        """
    )

    static let nested_with_scale = MappingCodeExample(
        title: "Nested with scale",
        code: """
        ZStack {
            Rectangle().fill(Color.blue)
            VStack {
                Rectangle().fill(Color.green)
                Rectangle().fill(Color.red)
            }
        }.scaleEffect(4)
        """
    )
}

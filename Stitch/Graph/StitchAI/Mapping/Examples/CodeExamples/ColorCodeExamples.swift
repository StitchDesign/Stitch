//
//  ColorCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/2/25.
//

import Foundation


struct ColorCodeExamples {
    static let colorAsValue = MappingCodeExample(
        title: "color as value",
        code:
    """
    Rectangle()
        .fill(Color("yellow") as! String)
    """
    )

    static let colorAsView = MappingCodeExample(
        title: "color as view",
        code:
    """
    Color.yellow
    """
    )
}

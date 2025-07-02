//
//  ScrollViewCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/1/25.
//

import Foundation
import SwiftUI


let scrollViewVStack = MappingCodeExample(
    title: "scrollViewVStack",
    code:
"""
ScrollView(.vertical) {
    VStack {
        Rectangle()
        Ellipse()
    }
}
"""
)

let scrollViewHStack = MappingCodeExample(
    title: "scrollViewHStack",
    code:
"""
ScrollView(.horizontal) {
    HStack {
        Rectangle()
        Ellipse()
    }
}
"""
)

let scrollViewNotTopLevel = MappingCodeExample(
    title: "scroll view not top level",
    code:
"""
ZStack {
    ScrollView(.vertical) {
        VStack {
            Rectangle()
        }
    }
}
"""
)

let scrollViewWithAllAxes = MappingCodeExample(
    title: "scroll view, all axes",
    code:
"""
ScrollView([.horizontal, .vertical]) {
    VStack {
        Rectangle()
    }
}
"""
)


let scrollViewWithoutExplicitAxes = MappingCodeExample(
    title: "scroll view without explicit axes",
    code:
 """
 ScrollView {
    VStack {
        Rectangle()
    }
 }
 """
)


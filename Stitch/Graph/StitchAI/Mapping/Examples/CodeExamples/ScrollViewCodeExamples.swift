//
//  ScrollViewCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/1/25.
//

import Foundation
import SwiftUI


struct ScrollViewCodeExamples {
    static let scrollViewVStack = MappingCodeExample(
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
    
    static let scrollViewHStack = MappingCodeExample(
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
    
    static let scrollViewNotTopLevel = MappingCodeExample(
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
    
    static let scrollViewWithAllAxes = MappingCodeExample(
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
    
    
    static let scrollViewWithoutExplicitAxes = MappingCodeExample(
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
    
}

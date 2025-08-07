//
//  PreprocessingExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/6/25.
//

import Foundation



// MARK: - Preprocessing Examples

struct PreprocessingCodeExamples {
    
    // Case 1: Single root view - should NOT be wrapped
    static let singleRootView = MappingCodeExample(
        title: "Single Root View (No Wrapping)",
        code: """
HStack {
    Rectangle()
    Ellipse()
}
"""
    )
    
    // Case 2: Multiple root views - should be wrapped in VStack
    static let multipleRootViews = MappingCodeExample(
        title: "Multiple Root Views (Should Wrap)",
        code: """
Rectangle()
Ellipse()
"""
    )
    
    // Case 3: Single stack with children - should NOT be wrapped
    static let singleStackWithChildren = MappingCodeExample(
        title: "Single Stack With Children (No Wrapping)",
        code: """
VStack {
    Text("Hello")
    Text("World")
    Rectangle()
        .fill(Color.blue)
}
"""
    )
    
    // Case 4: Mixed multiple views - should be wrapped
    static let mixedMultipleViews = MappingCodeExample(
        title: "Mixed Multiple Views (Should Wrap)",
        code: """
HStack {
    Rectangle()
    Ellipse()
}

Text("Between stacks")

VStack {
    Text("Hello")
    Text("World")
}
"""
    )
    
    // Case 5: Phone keypad example - multiple HStacks and other views
    static let phoneKeypadExample = MappingCodeExample(
        title: "Phone Keypad (Multiple Root Views)",
        code: """
VStack(alignment: .center) {
    VStack(alignment: .center) {
        ZStack(alignment: .center) {
            Ellipse()
            VStack {
                Text("1")
                Text("")
            }
        }
    }
}

HStack(alignment: .center) {
    VStack(alignment: .center) {
        ZStack(alignment: .center) {
            Ellipse()
            VStack {
                Text("4")
                Text("GHI")
            }
        }
    }
    VStack(alignment: .center) {
        ZStack(alignment: .center) {
            Ellipse()
            VStack {
                Text("5")
                Text("JKL")
            }
        }
    }
}

ZStack(alignment: .center) {
    Rectangle()
        .fill(Color.green)
        .cornerRadius(10.0)
    Image(systemName: "phone.fill")
        .foregroundColor(Color.white)
        .scaleEffect(0.5)
}
"""
    )
    
    // Case 6: Complex nested example - single root, should NOT wrap
    static let complexNestedExample = MappingCodeExample(
        title: "Complex Nested (Single Root)",
        code: """
ZStack {
    VStack {
        HStack {
            Rectangle()
                .fill(Color.red)
            Ellipse()
                .fill(Color.blue)
        }
        
        Text("Middle text")
            .font(.headline)
        
        HStack {
            Button("Left") { }
            Spacer()
            Button("Right") { }
        }
    }
    
    // Overlay content
    VStack {
        Spacer()
        Text("Overlay")
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
        Spacer()
    }
}
"""
    )
}

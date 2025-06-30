//
//  ViewNodeToSwiftUICodeTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 6/21/25.
//

import XCTest
import SwiftSyntax
import SwiftParser
@testable import Stitch

//class ViewNodeToSwiftUICodeTests: XCTestCase {
//    
//    // Test for complexModifierExample: Rectangle with frame modifier
//    func testComplexModifierExample() {
//        // Expected SwiftUI code for complexModifierExample
//        let expected = """
//        Rectangle()
//            .frame(width: 200, height: 100, alignment: .center)
//        """
//        
//        // Generate code from the ViewNode
//        let generated = swiftUICode(from: complexModifierExample)
//        
//        // Compare (trimming whitespace differences)
//        XCTAssertEqual(generated.trimmingCharacters(in: .whitespacesAndNewlines),
//                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
//    }
//    
//    // Test for example1: ZStack with Rectangle children
//    func testZStackWithRectangles() {
//        // Expected SwiftUI code for example1
//        let expected = """
//        ZStack {
//            Rectangle()
//                .fill(Color.blue)
//            Rectangle()
//                .fill(Color.green)
//        }
//        """
//        
//        // Generate code from the ViewNode
//        let generated = swiftUICode(from: example1)
//        
//        // Compare (trimming whitespace differences)
//        XCTAssertEqual(generated.trimmingCharacters(in: .whitespacesAndNewlines),
//                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
//    }
//    
//    // Test for example2: Simple Text
//    func testSimpleText() {
//        // Expected SwiftUI code for example2
//        let expected = """
//        Text("salut")
//        """
//        
//        // Generate code from the ViewNode
//        let generated = swiftUICode(from: example2)
//        
//        // Compare (trimming whitespace differences)
//        XCTAssertEqual(generated.trimmingCharacters(in: .whitespacesAndNewlines),
//                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
//    }
//    
//    // Test for example3: Text with modifiers
//    func testTextWithModifiers() {
//        // Expected SwiftUI code for example3
//        let expected = """
//        Text("salut")
//            .foregroundColor(Color.yellow)
//            .padding()
//        """
//        
//        // Generate code from the ViewNode
//        let generated = swiftUICode(from: example3)
//        
//        // Compare (trimming whitespace differences)
//        XCTAssertEqual(generated.trimmingCharacters(in: .whitespacesAndNewlines),
//                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
//    }
//    
//    // Test for example4: ZStack with Rectangle and VStack
//    func testNestedViews() {
//        // Expected SwiftUI code for example4
//        let expected = """
//        ZStack {
//            Rectangle()
//                .fill(Color.blue)
//            VStack {
//                Rectangle()
//                    .fill(Color.green)
//                Rectangle()
//                    .fill(Color.red)
//            }
//        }
//        """
//        
//        // Generate code from the ViewNode
//        let generated = swiftUICode(from: example4)
//        
//        // Compare (trimming whitespace differences)
//        XCTAssertEqual(generated.trimmingCharacters(in: .whitespacesAndNewlines),
//                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
//    }
//    
//    // Test for example5: Image with systemName
//    func testImageExample() {
//        // Expected SwiftUI code for example5
//        let expected = """
//        Image(systemName: "star.fill")
//        """
//        
//        // Generate code from the ViewNode
//        let generated = swiftUICode(from: example5)
//        
//        // Compare (trimming whitespace differences)
//        XCTAssertEqual(generated.trimmingCharacters(in: .whitespacesAndNewlines),
//                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
//    }
//}

//
//  IgnoreConditionalStatements.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 9/22/25.
//

import Testing
import SwiftSyntax
import SwiftParser
@testable import Stitch

struct IgnoreConditionalStatements {

    // MARK: - Helper Functions

    /// Applies conditional removal to input code and returns the transformed code
    func processCode(_ input: String) -> String {
        let sourceFile = Parser.parse(source: input)
        let rewriter = ConditionalRemovalRewriter(viewMode: .sourceAccurate)
        let rewritten = rewriter.rewrite(sourceFile)
        return rewritten.description
    }

    /// Normalize whitespace for comparison (removes extra spaces/newlines but preserves structure)
    func normalizeWhitespace(_ code: String) -> String {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line.trimmingCharacters(in: .whitespaces)
            }

        // Remove empty lines but keep structure
        return lines.filter { !$0.isEmpty || lines.count == 1 }
            .joined(separator: "\n")
    }

    // MARK: - Simple Examples

    @Test func testSimpleIfStatementRemoval() {
        let input = """
        let x = 1 + 1
        if x > 0 {
            let y = 5
        }
        let z = x + 1
        """

        let expected = """
        let x = 1 + 1
        let z = x + 1
        """

        let result = processCode(input)

        // The rewriter should remove the if statement entirely
        #expect(!result.contains("if x > 0"))
        #expect(!result.contains("let y = 5"))
        #expect(result.contains("let x = 1 + 1"))
        #expect(result.contains("let z = x + 1"))
    }

    @Test func testIfElseKeepsElseBlock() {
        let input = """
        let x = 1 + 1
        if x > 0 {
            let y = 5
        } else {
            let y = 9
        }
        let z = x + 1
        """

        let expected = """
        let x = 1 + 1
        let y = 9
        let z = x + 1
        """

        let result = processCode(input)

        // The rewriter should keep only the else block content
        #expect(!result.contains("if x > 0"))
        #expect(!result.contains("let y = 5"))
        #expect(result.contains("let y = 9"))
        #expect(result.contains("let x = 1 + 1"))
        #expect(result.contains("let z = x + 1"))
    }

    @Test func testTernaryExpressionReplacement() {
        let input = """
        let x = 1
        let y = x > 0 ? 2 : 3
        """

        let expected = """
        let x = 1
        let y = 3
        """

        let result = processCode(input)

        // The rewriter should replace the ternary with the false condition
        #expect(result.contains("let x = 1"))
        #expect(result.contains("let y = 3"))
        #expect(!result.contains("?"))
        #expect(!result.contains(":"))
        #expect(!result.contains("x > 0"))
    }

    // MARK: - Real World Examples

    @Test func testIfStatementInUpdateLayerInputs() {
        let input = """
        func updateLayerInputs() {
            let initialPositions = NATIVE_STITCH_PATCH_FUNCTIONS["positionPack || Patch"]([
                [PortValueDescription(value: 196.5, value_type: "number")],
                [PortValueDescription(value: 426, value_type: "number")]
            ])

            if dragPosition_6513468C_FB6A_4635_9BCB_E76EEBFB8D43.isEmpty {
                dragPosition_6513468C_FB6A_4635_9BCB_E76EEBFB8D43 = initialPositions[0]
            }
        }
        """

        let result = processCode(input)

        // The if statement should be completely removed
        #expect(result.contains("let initialPositions"))
        #expect(!result.contains("if dragPosition"))
        #expect(!result.contains("isEmpty"))
        #expect(!result.contains("dragPosition_6513468C_FB6A_4635_9BCB_E76EEBFB8D43 = initialPositions[0]"))
    }

    @Test func testTernaryExpressionInBody() {
        let input = """
        var body: some View {
            Ellipse()
                .fill([PortValueDescription(value: "#4A90E2FF", value_type: "color")])
                .position(dragPosition.isEmpty ? position_AD35BA4D : dragPosition)
                .frame([PortValueDescription(value: ["width":"30.0","height":"40.0"], value_type: "size")])
        }
        """

        let result = processCode(input)

        // The ternary should be replaced with just dragPosition (false condition)
        #expect(result.contains(".position(dragPosition)"))
        #expect(!result.contains("dragPosition.isEmpty"))
        #expect(!result.contains("?"))
        #expect(!result.contains("position_AD35BA4D"))
    }

    @Test func testTernaryExpressionInUpdateLayerInputs() {
        let input = """
        func updateLayerInputs() {
            let tapRgb = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([
                tapRandom_R[0],
                tapRandom_G[0],
                tapRandom_B[0],
                [PortValueDescription(value: 1, value_type: "number")]
            ])
            color_B40C1771 = tapRgb[0].isEmpty ? rgbColor_F12496B2[0] : tapRgb[0]
        }
        """

        let result = processCode(input)

        // The ternary should be replaced with tapRgb[0] (false condition)
        #expect(result.contains("color_B40C1771 = tapRgb[0]"))
        #expect(!result.contains("isEmpty"))
        #expect(!result.contains("?"))
        #expect(!result.contains("rgbColor_F12496B2"))
    }

    // MARK: - Edge Cases

    @Test func testNestedIfStatements() {
        let input = """
        if condition1 {
            if condition2 {
                doSomething()
            }
        } else {
            doSomethingElse()
        }
        """

        let result = processCode(input)

        // Should keep only the else block
        #expect(result.contains("doSomethingElse()"))
        #expect(!result.contains("condition1"))
        #expect(!result.contains("condition2"))
        #expect(!result.contains("doSomething()"))
    }

    @Test func testIfElseIfElse() {
        let input = """
        if x > 0 {
            print("positive")
        } else if x < 0 {
            print("negative")
        } else {
            print("zero")
        }
        """

        let result = processCode(input)

        // Should process the else-if recursively and end up with the final else
        #expect(result.contains("print(\"zero\")"))
        #expect(!result.contains("print(\"positive\")"))
        #expect(!result.contains("print(\"negative\")"))
    }

    @Test func testMultipleTernaryInSameLine() {
        let input = """
        let result = a > 0 ? (b > 0 ? 1 : 2) : (c > 0 ? 3 : 4)
        """

        let result = processCode(input)

        // Should replace nested ternaries, ultimately getting value 4
        #expect(result.contains("let result = "))
        // The nested ternaries should be resolved to the deepest false condition
        #expect(!result.contains("?"))
        #expect(!result.contains(":"))
    }

    // MARK: - Complete ContentView Examples

    @Test func testCompleteContentViewExample4() {
        let input = """
        struct ContentView: View {
            @State var dragPosition_6513468C: [PortValueDescription] = []

            var body: some View {
                VStack {
                    Rectangle()
                        .fill(color_6513468C)
                        .position(dragPosition_6513468C)
                }
            }

            func updateLayerInputs() {
                let initialPositions = NATIVE_STITCH_PATCH_FUNCTIONS["positionPack || Patch"]([
                    [PortValueDescription(value: 196.5, value_type: "number")]
                ])

                if dragPosition_6513468C.isEmpty {
                    dragPosition_6513468C = initialPositions[0]
                }
            }
        }
        """

        let result = SwiftUIViewVisitor.parseSwiftUICode(input)

        // The parsed result should not contain the if statement assignment
        let hasConditionalAssignment = result.bindingDeclarations.contains { decl in
            if case .stateMutation = decl.1 {
                return decl.0 == "dragPosition_6513468C"
            }
            return false
        }

        #expect(!hasConditionalAssignment)
    }

    @Test func testCompleteContentViewExample5() {
        let input = """
        struct ContentView: View {
            @State var dragPosition: [PortValueDescription] = []
            @State var position_AD35BA4D: [PortValueDescription] = []

            var body: some View {
                Ellipse()
                    .position(dragPosition.isEmpty ? position_AD35BA4D : dragPosition)
            }
        }
        """

        let result = SwiftUIViewVisitor.parseSwiftUICode(input)

        // After processing, the position modifier should only reference dragPosition
        #expect(!result.viewStack.isEmpty)

        if let firstView = result.viewStack.first {
            // Check that modifiers don't contain the ternary expression
            let positionModifier = firstView.modifiers.first { $0.name == .position }
            #expect(positionModifier != nil)

            // The position modifier should only have dragPosition as its argument after conditional removal
            if let positionModifier = positionModifier,
               case .other(let args) = positionModifier.arguments,
               let firstArg = args.first,
               case .stateAccess(let stateName) = firstArg.value {
                // Check that it's dragPosition, not a ternary or position_AD35BA4D
                #expect(stateName == "dragPosition")
            }
        }
    }

    @Test func testCompleteContentViewExample6() {
        let input = """
        struct ContentView: View {
            @State var color_B40C1771: [PortValueDescription] = []

            func updateLayerInputs() {
                let tapRgb = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([])
                let rgbColor_F12496B2 = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([])
                color_B40C1771 = tapRgb[0].isEmpty ? rgbColor_F12496B2[0] : tapRgb[0]
            }
        }
        """

        let result = SwiftUIViewVisitor.parseSwiftUICode(input)

        // Check that the ternary has been replaced with the false condition
        let hasCorrectAssignment = result.bindingDeclarations.contains { (name, initType) in
            if name == "color_B40C1771",
               case .stateMutation(let ref) = initType,
               case .subscriptRef(let subscriptData) = ref,
               case .ref(let baseRef) = subscriptData.subscriptType {
                // After conditional removal, should be assigning tapRgb[0]
                return baseRef == "tapRgb"
            }
            return false
        }

        #expect(hasCorrectAssignment)
    }
}
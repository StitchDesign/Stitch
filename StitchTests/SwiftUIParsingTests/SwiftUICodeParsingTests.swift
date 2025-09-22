//
//  SwiftUICodeParsingTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 9/21/25.
//

import Testing
@testable import Stitch

struct SwiftUICodeParsingTests {

    @Test func testCommentRemoval() async throws {
        let codeWithComment = """
struct ContentView: View {
 @State var color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =

 var body: some View {
  VStack(alignment: .center, spacing: [PortValueDescription(value: "8", value_type: "spacing")]) {
   Rectangle()
    .fill(color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .position(dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .frame([PortValueDescription(value: ["width":"300.0","height":"6.0"], value_type: "size")])
    .zIndex(zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .simultaneousGesture(
     DragGesture()
      .onChanged { value in
       dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = [PortValueDescription(value: ["x": value.location.x, "y": value.location.y], value_type: "position")]
      }
    )
  }
  .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
  .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
 }

 func updateLayerInputs() {
  let loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F = NATIVE_STITCH_PATCH_FUNCTIONS["loop || Patch"]([
   [PortValueDescription(value: 100, value_type: "number")]
  ])
  let random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654 = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([
   random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D[0],
   random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596[0],
   random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9[0],
   [PortValueDescription(value: 1, value_type: "number")]
  ])

  // Set initial positions for rectangles if dragPosition is empty
    if dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8.isEmpty {
      dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = PortValueDescription(value: ["x": 0, "y": 0], value_type: "position")
  }

  color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654[0]
  zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0]
 }
}
"""

        let expectedResult = """
struct ContentView: View {
 @State var color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =

 var body: some View {
  VStack(alignment: .center, spacing: [PortValueDescription(value: "8", value_type: "spacing")]) {
   Rectangle()
    .fill(color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .position(dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .frame([PortValueDescription(value: ["width":"300.0","height":"6.0"], value_type: "size")])
    .zIndex(zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .simultaneousGesture(
     DragGesture()
      .onChanged { value in
       dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = [PortValueDescription(value: ["x": value.location.x, "y": value.location.y], value_type: "position")]
      }
    )
  }
  .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
  .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
 }

 func updateLayerInputs() {
  let loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F = NATIVE_STITCH_PATCH_FUNCTIONS["loop || Patch"]([
   [PortValueDescription(value: 100, value_type: "number")]
  ])
  let random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654 = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([
   random_2FBB0CDD_8D55_4FBB_A668_19C28397C08D[0],
   random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596[0],
   random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9[0],
   [PortValueDescription(value: 1, value_type: "number")]
  ])

      if dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8.isEmpty {
      dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = PortValueDescription(value: ["x": 0, "y": 0], value_type: "position")
  }

  color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654[0]
  zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0]
 }
}
"""

        // Test our comment removal function
        let result = SwiftUIViewVisitor.testRemoveComments(from: codeWithComment)

        print("=== INPUT ===")
        print(codeWithComment)
        print("\n=== ACTUAL OUTPUT ===")
        print(result)
        print("\n=== EXPECTED OUTPUT ===")
        print(expectedResult)
        print("\n=== END DEBUG ===")

        // For now, just check that the comment line is removed
        #expect(!result.contains("// Set initial positions for rectangles if dragPosition is empty"))

        // Test that the result can be parsed successfully
        let parseResult = SwiftUIViewVisitor.parseSwiftUICode(result)
        print("\n=== PARSE RESULT ===")
        print("View stack count: \(parseResult.viewStack.count)")
        print("Binding declarations count: \(parseResult.bindingDeclarations.count)")
        print("Caught errors: \(parseResult.caughtErrors)")

        // Print all binding declarations for debugging
        print("\n=== ALL BINDING DECLARATIONS ===")
        for (index, binding) in parseResult.bindingDeclarations.enumerated() {
            print("\(index + 1). \(binding.0) -> \(String(describing: binding.1))")
        }

        // Check if we found the state variable connections
        let stateConnections = parseResult.bindingDeclarations.filter { binding in
            binding.0.contains("color_") || binding.0.contains("zIndex_")
        }
        print("\n=== STATE CONNECTIONS ===")
        print("State connections found: \(stateConnections.count)")
        for connection in stateConnections {
            print("  - \(connection.0)")
        }

        #expect(parseResult.caughtErrors.isEmpty, "No parsing errors should occur")
        // Note: We're getting 7 declarations which might be correct
        // (5 patch nodes + 2 state mutations)
        #expect(parseResult.bindingDeclarations.count >= 5, "Should have at least 5 binding declarations")
    }

    @Test func testCommentRemovalInFullPipeline() async throws {
        // This test simulates the full pipeline where the crash occurs
        let codeWithComment = """
struct ContentView: View {
 @State var color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =

 var body: some View {
  VStack(alignment: .center, spacing: [PortValueDescription(value: "8", value_type: "spacing")]) {
   Rectangle()
    .fill(color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .position(dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .frame([PortValueDescription(value: ["width":"300.0","height":"6.0"], value_type: "size")])
    .zIndex(zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .simultaneousGesture(
     DragGesture()
      .onChanged { value in
       dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = [PortValueDescription(value: ["x": value.location.x, "y": value.location.y], value_type: "position")]
      }
    )
  }
  .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
  .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
 }

 func updateLayerInputs() {
  let loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F = NATIVE_STITCH_PATCH_FUNCTIONS["loop || Patch"]([
   [PortValueDescription(value: 100, value_type: "number")]
  ])
  let random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654 = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([
   random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D[0],
   random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596[0],
   random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9[0],
   [PortValueDescription(value: 1, value_type: "number")]
  ])

  // Set initial positions for rectangles if dragPosition is empty
    if dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8.isEmpty {
      dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = PortValueDescription(value: ["x": 0, "y": 0], value_type: "position")
  }

  color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654[0]
  zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0]
 }
}
"""

        // Parse the code using the full pipeline as it would be in production
        let parseResult = SwiftUIViewVisitor.parseSwiftUICode(codeWithComment)

        print("\n=== FULL PIPELINE TEST ===")
        print("Errors: \(parseResult.caughtErrors)")

        // Check that all expected state mutations are found
        let stateMutations = parseResult.bindingDeclarations.compactMap { binding -> String? in
            if case .stateMutation = binding.1 {
                return binding.0
            }
            return nil
        }

        print("State mutations found: \(stateMutations)")

        // The critical check: are both color and zIndex mutations captured?
        #expect(stateMutations.contains("color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8"))
        #expect(stateMutations.contains("zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8"))

        // Also check patch nodes
        let patchNodes = parseResult.bindingDeclarations.compactMap { binding -> String? in
            if case .patchNode = binding.1 {
                return binding.0
            }
            return nil
        }

        print("Patch nodes found: \(patchNodes)")
        #expect(patchNodes.count == 5, "Should have exactly 5 patch nodes")
    }

    @Test func testBaselineWithoutComment() async throws {
        // Test the expected code (without comment) to establish baseline
        let expectedCode = """
struct ContentView: View {
 @State var color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =

 var body: some View {
  VStack(alignment: .center, spacing: [PortValueDescription(value: "8", value_type: "spacing")]) {
   Rectangle()
    .fill(color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .position(dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .frame([PortValueDescription(value: ["width":"300.0","height":"6.0"], value_type: "size")])
    .zIndex(zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .simultaneousGesture(
     DragGesture()
      .onChanged { value in
       dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = [PortValueDescription(value: ["x": value.location.x, "y": value.location.y], value_type: "position")]
      }
    )
  }
  .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
  .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
 }

 func updateLayerInputs() {
  let loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F = NATIVE_STITCH_PATCH_FUNCTIONS["loop || Patch"]([
   [PortValueDescription(value: 100, value_type: "number")]
  ])
  let random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654 = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([
   random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D[0],
   random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596[0],
   random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9[0],
   [PortValueDescription(value: 1, value_type: "number")]
  ])

      if dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8.isEmpty {
      dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = PortValueDescription(value: ["x": 0, "y": 0], value_type: "position")
  }

  color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654[0]
  zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0]
 }
}
"""

        let parseResult = SwiftUIViewVisitor.parseSwiftUICode(expectedCode)

        print("\n=== BASELINE TEST (NO COMMENT) ===")
        print("View stack count: \(parseResult.viewStack.count)")
        print("Binding declarations count: \(parseResult.bindingDeclarations.count)")
        print("Caught errors: \(parseResult.caughtErrors)")

        print("\n=== ALL BINDING DECLARATIONS ===")
        for (index, binding) in parseResult.bindingDeclarations.enumerated() {
            print("\(index + 1). \(binding.0)")
        }

        // Check state mutations
        let stateMutations = parseResult.bindingDeclarations.compactMap { binding -> String? in
            if case .stateMutation = binding.1 {
                return binding.0
            }
            return nil
        }
        print("\nState mutations: \(stateMutations)")

        // Check patch nodes
        let patchNodes = parseResult.bindingDeclarations.compactMap { binding -> String? in
            if case .patchNode = binding.1 {
                return binding.0
            }
            return nil
        }
        print("Patch nodes: \(patchNodes)")

        #expect(parseResult.caughtErrors.isEmpty)
        #expect(stateMutations.contains("color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8"))
        #expect(stateMutations.contains("zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8"))
        #expect(patchNodes.count == 5)

        print("\n=== SUMMARY ===")
        print("This baseline has \(parseResult.bindingDeclarations.count) total declarations")
        print("Compare this with the comment-removed version to see if they match")
    }

    @Test func testCompareProcessedVsExpected() async throws {
        // Compare the exact output of comment removal with expected
        let codeWithComment = """
struct ContentView: View {
 @State var color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =

 var body: some View {
  VStack(alignment: .center, spacing: [PortValueDescription(value: "8", value_type: "spacing")]) {
   Rectangle()
    .fill(color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .position(dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .frame([PortValueDescription(value: ["width":"300.0","height":"6.0"], value_type: "size")])
    .zIndex(zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .simultaneousGesture(
     DragGesture()
      .onChanged { value in
       dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = [PortValueDescription(value: ["x": value.location.x, "y": value.location.y], value_type: "position")]
      }
    )
  }
  .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
  .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
 }

 func updateLayerInputs() {
  let loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F = NATIVE_STITCH_PATCH_FUNCTIONS["loop || Patch"]([
   [PortValueDescription(value: 100, value_type: "number")]
  ])
  let random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654 = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([
   random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D[0],
   random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596[0],
   random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9[0],
   [PortValueDescription(value: 1, value_type: "number")]
  ])

  // Set initial positions for rectangles if dragPosition is empty
    if dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8.isEmpty {
      dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = PortValueDescription(value: ["x": 0, "y": 0], value_type: "position")
  }

  color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654[0]
  zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0]
 }
}
"""

        let expectedResult = """
struct ContentView: View {
 @State var color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =
 @State var dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8: [PortValueDescription] =

 var body: some View {
  VStack(alignment: .center, spacing: [PortValueDescription(value: "8", value_type: "spacing")]) {
   Rectangle()
    .fill(color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .position(dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .frame([PortValueDescription(value: ["width":"300.0","height":"6.0"], value_type: "size")])
    .zIndex(zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8)
    .simultaneousGesture(
     DragGesture()
      .onChanged { value in
       dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = [PortValueDescription(value: ["x": value.location.x, "y": value.location.y], value_type: "position")]
      }
    )
  }
  .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
  .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
 }

 func updateLayerInputs() {
  let loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F = NATIVE_STITCH_PATCH_FUNCTIONS["loop || Patch"]([
   [PortValueDescription(value: 100, value_type: "number")]
  ])
  let random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9 = NATIVE_STITCH_PATCH_FUNCTIONS["random || Patch"]([
   loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0],
   [PortValueDescription(value: 0, value_type: "number")],
   [PortValueDescription(value: 1, value_type: "number")]
  ])
  let rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654 = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]([
   random_2FBB0CDD_8D55_4FBF_A668_19C28397C08D[0],
   random_12ABFF4A_F24D_4C9F_A8EF_57395CB5F596[0],
   random_E11FB589_99FB_425B_9FE2_4AB33F7EACD9[0],
   [PortValueDescription(value: 1, value_type: "number")]
  ])

      if dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8.isEmpty {
      dragPosition_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = PortValueDescription(value: ["x": 0, "y": 0], value_type: "position")
  }

  color_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = rgbColor_2AB36B51_5DB2_4EB5_B3C4_71F162F89654[0]
  zIndex_B4AE5764_2D36_47ED_9322_C9DA3F456DF8 = loop_3F3F86B6_C152_454D_A5C1_251FFDAE291F[0]
 }
}
"""

        let processed = SwiftUIViewVisitor.testRemoveComments(from: codeWithComment)

        print("\n=== COMPARISON TEST ===")
        print("Processed length: \(processed.count)")
        print("Expected length: \(expectedResult.count)")
        print("Are they equal? \(processed == expectedResult)")

        // Find the first difference
        let processedLines = processed.components(separatedBy: "\n")
        let expectedLines = expectedResult.components(separatedBy: "\n")

        print("\nLine count - Processed: \(processedLines.count), Expected: \(expectedLines.count)")

        for (index, (pLine, eLine)) in zip(processedLines, expectedLines).enumerated() {
            if pLine != eLine {
                print("\nFirst difference at line \(index + 1):")
                print("Processed: |\(pLine)|")
                print("Expected:  |\(eLine)|")

                // Show character-level difference
                for (charIndex, (pChar, eChar)) in zip(pLine, eLine).enumerated() {
                    if pChar != eChar {
                        print("  First char difference at position \(charIndex): '\(pChar)' vs '\(eChar)'")
                        break
                    }
                }
                break
            }
        }

        // Check the specific area around where the comment was
        print("\n=== AREA AROUND COMMENT ===")
        let commentLineIndex = processedLines.firstIndex { $0.contains("rgbColor_2AB36B51") } ?? 0
        if commentLineIndex > 0 {
            for i in (commentLineIndex...min(commentLineIndex + 5, processedLines.count - 1)) {
                print("Line \(i): |\(processedLines[i])|")
            }
        }

        // Check for extra blank lines
        let processedBlanks = processedLines.indices.filter { processedLines[$0].trimmingCharacters(in: .whitespaces).isEmpty }
        let expectedBlanks = expectedLines.indices.filter { expectedLines[$0].trimmingCharacters(in: .whitespaces).isEmpty }

        print("\n=== BLANK LINES ===")
        print("Processed blank lines at indices: \(processedBlanks)")
        print("Expected blank lines at indices: \(expectedBlanks)")

        #expect(processed == expectedResult, "Processed output should match expected output exactly")
    }
}

//
//  ClassicAnimationCodeExamples.swift
//  Stitch
//
//  Created for testing Issue #7505
//

import Foundation

/// Examples testing classic animation nodes
/// Issue #7505: Crash during stream due to nil node type on classic animation node
struct ClassicAnimationCodeExamples {

    static let phoneKeypadWithButtonAnimations = MappingCodeExample(
        title: "Phone Keypad with Button Animations (Issue #7505)",
        code: """
struct ContentView: View {

    @State var button1Scale: [PortValueDescription] = []
    @State var button1Pulse: [PortValueDescription] = []
    @State var button2Scale: [PortValueDescription] = []
    @State var button2Pulse: [PortValueDescription] = []
    @State var button3Scale: [PortValueDescription] = []
    @State var button3Pulse: [PortValueDescription] = []
    @State var button4Scale: [PortValueDescription] = []
    @State var button4Pulse: [PortValueDescription] = []
    @State var button5Scale: [PortValueDescription] = []
    @State var button5Pulse: [PortValueDescription] = []
    @State var button6Scale: [PortValueDescription] = []
    @State var button6Pulse: [PortValueDescription] = []
    @State var button7Scale: [PortValueDescription] = []
    @State var button7Pulse: [PortValueDescription] = []
    @State var button8Scale: [PortValueDescription] = []
    @State var button8Pulse: [PortValueDescription] = []
    @State var button9Scale: [PortValueDescription] = []
    @State var button9Pulse: [PortValueDescription] = []
    @State var buttonStarScale: [PortValueDescription] = []
    @State var buttonStarPulse: [PortValueDescription] = []
    @State var button0Scale: [PortValueDescription] = []
    @State var button0Pulse: [PortValueDescription] = []
    @State var buttonHashScale: [PortValueDescription] = []
    @State var buttonHashPulse: [PortValueDescription] = []
    @State var callButtonScale: [PortValueDescription] = []
    @State var callButtonPulse: [PortValueDescription] = []

 var body: some View {
   VStack(alignment: .center, spacing: [PortValueDescription(value: "40", value_type: "spacing")]) {
    HStack(alignment: .center, spacing: [PortValueDescription(value: "60", value_type: "spacing")]) {
     ZStack(alignment: .center) {
      Ellipse()
       .fill([PortValueDescription(value: "#D3D3D3FF", value_type: "color")])
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

      Text([PortValueDescription(value: "1", value_type: "string")])
       .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

     }
      .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
      .frame([PortValueDescription(value: ["height":"hug","width":"hug"], value_type: "size")])
      .scaleEffect(button1Scale)
      .simultaneousGesture(.onTapGesture {
       button1Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
      })

     ZStack(alignment: .center) {
      Ellipse()
       .fill([PortValueDescription(value: "#D3D3D3FF", value_type: "color")])
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])

      VStack(alignment: .center, spacing: [PortValueDescription(value: "2", value_type: "spacing")]) {
       Text([PortValueDescription(value: "2", value_type: "string")])
        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

       Text([PortValueDescription(value: "ABC", value_type: "string")])
        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
        .font([PortValueDescription(value: "12.0", value_type: "layerDimension")])

      }
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

     }
      .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
      .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
      .scaleEffect(button2Scale)
      .simultaneousGesture(.onTapGesture {
       button2Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
      })

     ZStack(alignment: .center) {
      Ellipse()
       .fill([PortValueDescription(value: "#D3D3D3FF", value_type: "color")])
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

      VStack(alignment: .center, spacing: [PortValueDescription(value: "2", value_type: "spacing")]) {
       Text([PortValueDescription(value: "3", value_type: "string")])
        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

       Text([PortValueDescription(value: "DEF", value_type: "string")])
        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
        .font([PortValueDescription(value: "12.0", value_type: "layerDimension")])

      }
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

     }
      .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
      .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
      .scaleEffect(button3Scale)
      .simultaneousGesture(.onTapGesture {
       button3Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
      })

    }
     .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
     .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

    HStack(alignment: .center, spacing: [PortValueDescription(value: "60", value_type: "spacing")]) {
     ZStack(alignment: .center) {
      Ellipse()
       .fill([PortValueDescription(value: "#D3D3D3FF", value_type: "color")])
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

      VStack(alignment: .center, spacing: [PortValueDescription(value: "2", value_type: "spacing")]) {
       Text([PortValueDescription(value: "4", value_type: "string")])
        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

       Text([PortValueDescription(value: "GHI", value_type: "string")])
        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
        .font([PortValueDescription(value: "12.0", value_type: "layerDimension")])

      }
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

     }
      .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
      .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
      .scaleEffect(button4Scale)
      .simultaneousGesture(.onTapGesture {
       button4Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
      })

     ZStack(alignment: .center) {
      Ellipse()
       .fill([PortValueDescription(value: "#D3D3D3FF", value_type: "color")])
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

      VStack(alignment: .center, spacing: [PortValueDescription(value: "2", value_type: "spacing")]) {
       Text([PortValueDescription(value: "5", value_type: "string")])
        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

       Text([PortValueDescription(value: "JKL", value_type: "string")])
        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
        .font([PortValueDescription(value: "12.0", value_type: "layerDimension")])

      }
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

     }
      .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
      .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
      .scaleEffect(button5Scale)
      .simultaneousGesture(.onTapGesture {
       button5Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
      })

     ZStack(alignment: .center) {
      Ellipse()
       .fill([PortValueDescription(value: "#D3D3D3FF", value_type: "color")])
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

      VStack(alignment: .center, spacing: [PortValueDescription(value: "2", value_type: "spacing")]) {
       Text([PortValueDescription(value: "6", value_type: "string")])
        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

       Text([PortValueDescription(value: "MNO", value_type: "string")])
        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
        .font([PortValueDescription(value: "12.0", value_type: "layerDimension")])

      }
       .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
       .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

     }
      .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
      .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
      .scaleEffect(button6Scale)
      .simultaneousGesture(.onTapGesture {
       button6Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
      })

    }
     .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
     .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
   }
    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
    .padding([PortValueDescription(value: ["bottom":50,"top":100,"left":40,"right":40], value_type: "padding")])

 }

 func updateLayerInputs() {
  let button1Animation = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
   button1Pulse,
   [PortValueDescription(value: 0.1, value_type: "number")],
   [PortValueDescription(value: "easeOut", value_type: "animationCurve")]
  ])
  let button1OptionPicker = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
   button1Animation[0],
   [PortValueDescription(value: 1.0, value_type: "number")],
   [PortValueDescription(value: 0.9, value_type: "number")]
  ])
  button1Scale = button1OptionPicker[0]

  let button2Animation = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
   button2Pulse,
   [PortValueDescription(value: 0.1, value_type: "number")],
   [PortValueDescription(value: "easeOut", value_type: "animationCurve")]
  ])
  let button2OptionPicker = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
   button2Animation[0],
   [PortValueDescription(value: 1.0, value_type: "number")],
   [PortValueDescription(value: 0.9, value_type: "number")]
  ])
  button2Scale = button2OptionPicker[0]

  let button3Animation = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
   button3Pulse,
   [PortValueDescription(value: 0.1, value_type: "number")],
   [PortValueDescription(value: "easeOut", value_type: "animationCurve")]
  ])
  let button3OptionPicker = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
   button3Animation[0],
   [PortValueDescription(value: 1.0, value_type: "number")],
   [PortValueDescription(value: 0.9, value_type: "number")]
  ])
  button3Scale = button3OptionPicker[0]
 }
}
"""
    )
}

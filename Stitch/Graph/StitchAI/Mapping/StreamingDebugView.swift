//
//  StreamingDebugView.swift
//  Stitch
//
//  Created for debugging AI streaming graph merge logic.
//  Simulates incremental streaming by adding tokens from expected code.
//

import SwiftUI
import SwiftSyntax
import SwiftParser
import StitchSchemaKit

/// Debug view that simulates AI streaming to reproduce connection duplication bugs
struct StreamingDebugView: View {

    // MARK: - State

    /// The complete expected code (what we expect from AI after full stream)
    @State private var expectedCode: String = """
    struct ContentView: View {

        @State var button1Pulse: [PortValueDescription] = []
        @State var button1Scale: [PortValueDescription] = []
        @State var button2Pulse: [PortValueDescription] = []
        @State var button2Scale: [PortValueDescription] = []
        @State var button3Pulse: [PortValueDescription] = []
        @State var button3Scale: [PortValueDescription] = []
        @State var button4Pulse: [PortValueDescription] = []
        @State var button4Scale: [PortValueDescription] = []
        @State var button5Pulse: [PortValueDescription] = []
        @State var button5Scale: [PortValueDescription] = []
        @State var button6Pulse: [PortValueDescription] = []
        @State var button6Scale: [PortValueDescription] = []
        @State var button7Pulse: [PortValueDescription] = []
        @State var button7Scale: [PortValueDescription] = []
        @State var button8Pulse: [PortValueDescription] = []
        @State var button8Scale: [PortValueDescription] = []
        @State var button9Pulse: [PortValueDescription] = []
        @State var button9Scale: [PortValueDescription] = []
        @State var buttonStarPulse: [PortValueDescription] = []
        @State var buttonStarScale: [PortValueDescription] = []
        @State var button0Pulse: [PortValueDescription] = []
        @State var button0Scale: [PortValueDescription] = []
        @State var buttonHashPulse: [PortValueDescription] = []
        @State var buttonHashScale: [PortValueDescription] = []
        @State var callButtonPulse: [PortValueDescription] = []
        @State var callButtonScale: [PortValueDescription] = []
        @State var deleteButtonPulse: [PortValueDescription] = []
        @State var deleteButtonScale: [PortValueDescription] = []

        var body: some View {
                VStack(alignment: .center, spacing: [PortValueDescription(value: "24", value_type: "spacing")]) {
                    Text([PortValueDescription(value: "1 (234) 567-8900", value_type: "string")])
                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                        .font([PortValueDescription(value: "36.0", value_type: "layerDimension")])

                    Text([PortValueDescription(value: "Add Number", value_type: "string")])
                        .foregroundColor([PortValueDescription(value: "#007AFFFF", value_type: "color")])
                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])

                    Spacer()


                    VStack(alignment: .center, spacing: [PortValueDescription(value: "20", value_type: "spacing")]) {
                        HStack(alignment: .center, spacing: [PortValueDescription(value: "30", value_type: "spacing")]) {
                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])

                                Text([PortValueDescription(value: "1", value_type: "string")])
                                    .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                .scaleEffect(button1Scale)
                                .onTapGesture {
                                    button1Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                    Text([PortValueDescription(value: "2", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                    Text([PortValueDescription(value: "ABC", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                .scaleEffect(button2Scale)
                                .onTapGesture {
                                    button2Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                    Text([PortValueDescription(value: "3", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                    Text([PortValueDescription(value: "DEF", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                .scaleEffect(button3Scale)
                                .onTapGesture {
                                    button3Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                        }
                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                        HStack(alignment: .center, spacing: [PortValueDescription(value: "30", value_type: "spacing")]) {
                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                    Text([PortValueDescription(value: "4", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                    Text([PortValueDescription(value: "GHI", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                .scaleEffect(button4Scale)
                                .onTapGesture {
                                    button4Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                    Text([PortValueDescription(value: "5", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                    Text([PortValueDescription(value: "JKL", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                .scaleEffect(button5Scale)
                                .onTapGesture {
                                    button5Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                    Text([PortValueDescription(value: "6", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                    Text([PortValueDescription(value: "MNO", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                .scaleEffect(button6Scale)
                                .onTapGesture {
                                    button6Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                        }
                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                        HStack(alignment: .center, spacing: [PortValueDescription(value: "30", value_type: "spacing")]) {
                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                    Text([PortValueDescription(value: "7", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                    Text([PortValueDescription(value: "PQRS", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                .scaleEffect(button7Scale)
                                .onTapGesture {
                                    button7Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                    Text([PortValueDescription(value: "8", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                    Text([PortValueDescription(value: "TUV", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                .scaleEffect(button8Scale)
                                .onTapGesture {
                                    button8Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                    Text([PortValueDescription(value: "9", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                    Text([PortValueDescription(value: "WXYZ", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "10.0", value_type: "layerDimension")])

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                .scaleEffect(button9Scale)
                                .onTapGesture {
                                    button9Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                        }
                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                        HStack(alignment: .center, spacing: [PortValueDescription(value: "30", value_type: "spacing")]) {
                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])

                                Text([PortValueDescription(value: "*", value_type: "string")])
                                    .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .font([PortValueDescription(value: "40.0", value_type: "layerDimension")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["height":"hug","width":"hug"], value_type: "size")])
                                .scaleEffect(buttonStarScale)
                                .onTapGesture {
                                    buttonStarPulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])

                                VStack(alignment: .center, spacing: [PortValueDescription(value: "0", value_type: "spacing")]) {
                                    Text([PortValueDescription(value: "0", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                        .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                                    Text([PortValueDescription(value: "+", value_type: "string")])
                                        .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])

                                }
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["height":"hug","width":"hug"], value_type: "size")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["height":"hug","width":"hug"], value_type: "size")])
                                .scaleEffect(button0Scale)
                                .onTapGesture {
                                    button0Pulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                            ZStack(alignment: .center) {
                                Ellipse()
                                    .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .frame([PortValueDescription(value: ["height":"80.0","width":"80.0"], value_type: "size")])

                                Text([PortValueDescription(value: "#", value_type: "string")])
                                    .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                    .font([PortValueDescription(value: "40.0", value_type: "layerDimension")])

                            }
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                                .scaleEffect(buttonHashScale)
                                .onTapGesture {
                                    buttonHashPulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                                }

                        }
                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                    }
                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                    Spacer()


                    HStack(alignment: .center, spacing: [PortValueDescription(value: "60", value_type: "spacing")]) {
                        ZStack(alignment: .center) {
                            Ellipse()
                                .fill([PortValueDescription(value: "#FF9500FF", value_type: "color")])
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["width":"70.0","height":"70.0"], value_type: "size")])

                            Text([PortValueDescription(value: "📞", value_type: "string")])
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .font([PortValueDescription(value: "32.0", value_type: "layerDimension")])

                        }
                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                            .frame([PortValueDescription(value: ["height":"hug","width":"hug"], value_type: "size")])
                            .scaleEffect(callButtonScale)
                            .onTapGesture {
                                callButtonPulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                            }

                        ZStack(alignment: .center) {
                            Ellipse()
                                .fill([PortValueDescription(value: "#D1D1D6FF", value_type: "color")])
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .frame([PortValueDescription(value: ["height":"50.0","width":"50.0"], value_type: "size")])

                            Text([PortValueDescription(value: "⌫", value_type: "string")])
                                .foregroundColor([PortValueDescription(value: "#000000FF", value_type: "color")])
                                .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                                .font([PortValueDescription(value: "24.0", value_type: "layerDimension")])

                        }
                            .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                            .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                            .scaleEffect(deleteButtonScale)
                            .onTapGesture {
                                deleteButtonPulse = [PortValueDescription(value: STITCH_GRAPH_TIME, value_type: "pulse")]
                            }

                    }
                        .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                        .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])

                }
                    .offset([PortValueDescription(value: ["x":0,"y":0], value_type: "position")])
                    .frame([PortValueDescription(value: ["width":"hug","height":"hug"], value_type: "size")])
                    .padding([PortValueDescription(value: ["left":20,"bottom":40,"right":20,"top":40], value_type: "padding")])

        }

        func updateLayerInputs() {
            let optionPicker1 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                button1Pulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animation1 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPicker1[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            button1Scale = animation1[0]

            let optionPicker2 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                button2Pulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animation2 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPicker2[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            button2Scale = animation2[0]

            let optionPicker3 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                button3Pulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animation3 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPicker3[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            button3Scale = animation3[0]

            let optionPicker4 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                button4Pulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animation4 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPicker4[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            button4Scale = animation4[0]

            let optionPicker5 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                button5Pulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animation5 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPicker5[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            button5Scale = animation5[0]

            let optionPicker6 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                button6Pulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animation6 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPicker6[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            button6Scale = animation6[0]

            let optionPicker7 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                button7Pulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animation7 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPicker7[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            button7Scale = animation7[0]

            let optionPicker8 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                button8Pulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animation8 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPicker8[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            button8Scale = animation8[0]

            let optionPicker9 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                button9Pulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animation9 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPicker9[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            button9Scale = animation9[0]

            let optionPickerStar = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                buttonStarPulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animationStar = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPickerStar[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            buttonStarScale = animationStar[0]

            let optionPicker0 = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                button0Pulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animation0 = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPicker0[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            button0Scale = animation0[0]

            let optionPickerHash = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                buttonHashPulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animationHash = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPickerHash[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            buttonHashScale = animationHash[0]

            let optionPickerCall = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                callButtonPulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animationCall = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPickerCall[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            callButtonScale = animationCall[0]

            let optionPickerDelete = NATIVE_STITCH_PATCH_FUNCTIONS["optionPicker || Patch"]([
                deleteButtonPulse,
                [PortValueDescription(value: 1, value_type: "number")],
                [PortValueDescription(value: 0.85, value_type: "number")]
            ])
            let animationDelete = NATIVE_STITCH_PATCH_FUNCTIONS["classicAnimation || Patch"]([
                optionPickerDelete[0],
                [PortValueDescription(value: 0.15, value_type: "number")],
                [PortValueDescription(value: "quadraticOut", value_type: "animationCurve")]
            ])
            deleteButtonScale = animationDelete[0]
        }


    }
    """

    /// The code we've streamed so far (built incrementally)
    @State private var streamedSoFar: String = ""

    /// How many characters to add per streaming step
    @State private var tokenChunkSize: Int = 120

    /// Current graph entity (merged state)
    @State private var currentGraphEntity: GraphEntity = .createEmpty()

    /// Stats about current graph
    @State private var nodeCount: Int = 0
    @State private var connectionCount: Int = 0
    @State private var lastUpdateInfo: String = ""

    /// Fake document for graph processing
    @State private var fakeDocument: StitchDocumentViewModel?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            Text("Streaming Debug View")
                .font(.title2).bold()

            Text("Simulates incremental AI streaming to debug connection merge logic")
                .font(.caption)
                .foregroundColor(.secondary)

            // Controls
            HStack(spacing: 12) {
                Button("Reset") { reset() }
                    .buttonStyle(.bordered)

                Button("Add Next \(tokenChunkSize) Chars") { addNextTokens() }
                    .buttonStyle(.borderedProminent)
                    .disabled(streamedSoFar.count >= expectedCode.count)

                Stepper("Chunk Size: \(tokenChunkSize)", value: $tokenChunkSize, in: 10...500, step: 10)
                    .frame(width: 250)
            }
            .padding(.vertical, 8)

            // Graph Stats
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Nodes: \(nodeCount)")
                        .font(.headline)
                    Text("Connections: \(connectionCount)")
                        .font(.headline)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                VStack(alignment: .leading) {
                    Text("Progress: \(streamedSoFar.count) / \(expectedCode.count) chars")
                        .font(.subheadline)
                    Text(lastUpdateInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Three-column layout
            HStack(spacing: 16) {
                // Column 1: Expected Code
                stageView(
                    title: "Expected Code (Full)",
                    text: expectedCode,
                    isEditor: true,
                    editorBinding: $expectedCode
                )

                // Column 2: Streamed So Far
                stageView(
                    title: "Streamed So Far",
                    text: streamedSoFar.isEmpty ? "—" : streamedSoFar,
                    isEditor: false,
                    editorBinding: nil
                )

                // Column 3: Graph Structure
                stageView(
                    title: "Current Graph Structure",
                    text: formatGraphEntity(currentGraphEntity),
                    isEditor: false,
                    editorBinding: nil
                )
            }
        }
        .padding()
        .onAppear {
            fakeDocument = StitchDocumentViewModel.createEmpty()
            reset()
        }
    }

    // MARK: - Actions

    private func reset() {
        streamedSoFar = ""
        currentGraphEntity = .createEmpty()
        nodeCount = 0
        connectionCount = 0
        lastUpdateInfo = "Ready to start streaming"

        // Reset fake document by creating a new empty one
        fakeDocument = StitchDocumentViewModel.createEmpty()
    }

    private func addNextTokens() {
        guard let doc = fakeDocument else { return }

        // Calculate how many characters to add
        let remainingChars = expectedCode.count - streamedSoFar.count
        let charsToAdd = min(tokenChunkSize, remainingChars)

        guard charsToAdd > 0 else { return }

        // Add next chunk
        let endIndex = expectedCode.index(expectedCode.startIndex, offsetBy: streamedSoFar.count + charsToAdd)
        streamedSoFar = String(expectedCode[..<endIndex])

        log("🎬 STREAMING DEBUG: Adding \(charsToAdd) chars (total: \(streamedSoFar.count)/\(expectedCode.count))")

        // Parse with streaming flag
        let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(streamedSoFar, isStreaming: true)

        log("📝 Parsed: \(codeParserResult.viewStack.count) views")

        // Derive actions and create graph
        Task(priority: .high) {
            do {
                let stitchActionsResult = try await codeParserResult.deriveStitchActions(
                    bindingDeclarations: codeParserResult.bindingDeclarations,
                    document: doc,
                    isStreaming: true
                )

                await MainActor.run {
                    log("📊 Actions derived: \(stitchActionsResult.graphData.layer_data_list.count) layers, \(stitchActionsResult.graphData.patchNodes.count) patch nodes")

                    // Get current graph entity before merge
                    let beforeMerge = doc.graph.createSchema()

                    // Process with streaming flag - this will call mergeWithStreamedGraph
                    stitchActionsResult.processAIGraph(
                        document: doc,
                        currentGraphEntity: beforeMerge,
                        isStreaming: true
                    )

                    // Update our tracking
                    currentGraphEntity = doc.graph.createSchema()
                    updateStats()
                }
            } catch {
                log("❌ Error during streaming: \(error)")
                lastUpdateInfo = "Error: \(error)"
            }
        }
    }

    private func updateStats() {
        nodeCount = currentGraphEntity.nodes.count

        // Count connections (upstream connections in patch nodes)
        connectionCount = currentGraphEntity.nodes.reduce(0) { count, node in
            count + (node.patchNodeEntity?.inputs.filter {
                if case .upstreamConnection = $0.portData { return true }
                return false
            }.count ?? 0)
        }

        lastUpdateInfo = "Updated at \(Date().formatted(date: .omitted, time: .standard))"
    }

    // MARK: - Helpers

    @ViewBuilder
    private func stageView(title: String,
                           text: String,
                           isEditor: Bool = false,
                           editorBinding: Binding<String>? = nil) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            if isEditor, let binding = editorBinding {
                TextEditor(text: binding)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .border(Color.secondary)
            } else {
                ScrollView {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .border(Color.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func formatGraphEntity(_ graph: GraphEntity) -> String {
        var output = "GraphEntity(\n"
        output += "  nodes: [\n"

        for node in graph.nodes {
            output += "    \(node.id.uuidString.prefix(8))... - \(node.title)\n"

            // Show patch inputs if available
            if let patchEntity = node.patchNodeEntity {
                for (index, input) in patchEntity.inputs.enumerated() {
                    switch input.portData {
                    case .upstreamConnection(let coord):
                        output += "      input[\(index)] <- \(coord.nodeId.uuidString.prefix(8))...\n"
                    case .values(let values):
                        output += "      input[\(index)] = \(values.count) value(s)\n"
                    }
                }
            }
        }

        output += "  ],\n"
        output += "  orderedSidebarLayers: [\(graph.orderedSidebarLayers.count) items]\n"
        output += ")"

        return output
    }
}

#if DEBUG
struct StreamingDebugView_Previews: PreviewProvider {
    static var previews: some View {
        StreamingDebugView()
            .frame(minWidth: 1600, minHeight: 900)
    }
}
#endif

//
//  ColorGradientPickerView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/26/23.
//

import SwiftUI
import StitchSchemaKit

let COLOR_ORB_WRAPPING_COLOR = Color(uiColor: UIColor.systemGray3)

struct ColorOrbWrapperModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .padding(2)
            .background {
//                Circle().fill(.white) // original
                Circle().fill(COLOR_ORB_WRAPPING_COLOR)
            }
    }
}

struct StitchColorPickerOrb: View {

    let chosenColor: Color
    let isMultiselectInspectorInputWithHeterogenousValues: Bool

    var body: some View {
        Group {
            if isMultiselectInspectorInputWithHeterogenousValues {
                Ellipse()
                    .fill(AngularGradient(
                        gradient: Gradient(colors: [
                            Color.blue,
                            Color.pink,
                            Color.yellow,
                            Color.green
                        ]),
                        center: .center))
            } else {
                Circle().fill(chosenColor)
            }
        }
        .frame(width: NODE_ROW_HEIGHT, // req'd for e.g. ports that have labels
               height: NODE_ROW_HEIGHT)
        .modifier(ColorOrbWrapperModifier())
    }
}

// fka ColorGradientPickerView
struct StitchColorPickerView: View {
    // TODO: opening or closing the color-gradient-picker view should disable nodes copy-paste shortcut
    @State private var show: Bool = false

    let rowId: NodeIOCoordinate?
    let inputLayerNodeRowData: InputLayerNodeRowData?
    let fieldCoordinate: FieldCoordinate
    let isFieldInsideLayerInspector: Bool
    var isForPreviewWindowBackgroundPicker: Bool = false
    var isForIPhone: Bool = false

    //    @State var currentColor: Color = .clear
    //    @State var chosenColor: Color = .red
    @Binding var chosenColor: Color
    let graph: GraphState
        
    @MainActor
    var isMultiselectInspectorInputWithHeterogenousValues: Bool {
        if let inputLayerNodeRowData = inputLayerNodeRowData {
            @Bindable var inputLayerNodeRowData = inputLayerNodeRowData
            return inputLayerNodeRowData.fieldHasHeterogenousValues(
                fieldCoordinate.fieldIndex,
                isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        } else {
            return false
        }
    }
    
    var body: some View {

        ZStack {
            // DEBUG:
            //            colorPopover.padding()

            StitchColorPickerOrb(chosenColor: chosenColor,
                                 isMultiselectInspectorInputWithHeterogenousValues: isMultiselectInspectorInputWithHeterogenousValues)
                .popover(isPresented: $show, content: {
                    colorPopover.padding()
                })
                .onTapGesture {
                    show.toggle()
                }
        } // ZStack
    }

    var debugColorCircle: some View {
        Circle().fill(chosenColor)
            .stroke(.black)
            .frame(width: 60)
            .padding()
    }

    @MainActor
    var colorPopover: some View {
        HStack(alignment: .top) {

            //            debugColorCircle

            VStack(alignment: .leading) {
                sliders
                hexEditAndDisplay.padding([.top])
            }.padding([.leading])

            colorGrid.padding()
        }
        // TODO: try to get `ViewThatFits` to work? Need to specify axis etc.? Or figure out why `GraphUIState.isPortraitMode` is not accurate on iPhone? (Maybe because on iPhone we don't render the ContentView that is responsible for reading screen size and updating GraphUIState`?)
        .scaleEffect(isForIPhone ? 0.7 : 1)
        .onAppear {
            //            log("StitchColorPickerView: onAppear: hexEdit was: \(self.hexEdit)")
            self.hexEdit = chosenColor.asHexDisplay
            //            log("StitchColorPickerView: onAppear: hexEdit is now: \(self.hexEdit)")
        }
        .onDisappear {
            //            log("StitchColorPickerView: onDisappear: hexEdit was: \(self.hexEdit)")
            // treat closing the popover as committing the hex edit
            //            self.chosenColor = .init(hex: self.hexEdit)

            self.chosenColor = ColorConversionUtils.hexToColor(self.hexEdit) ?? .black

            // Not needed?: defocus the field
            self.hexFocus = false

            // Reset hexEdit field`
            self.hexEdit = ""

            //            log("StitchColorPickerView: onDisappear: hexEdit is now: \(self.hexEdit)")
        }
        // a cycle: changing current color causes us to change the hexEdit; but changing the hexEdit causes us to change current color;
        // so we only change currentColor to hexString when we submit text field
        .onChange(of: self.chosenColor) { _, newValue in
            //            log("StitchColorPickerView: onChange of self.chosenColor: hexEdit was: \(self.hexEdit)")

            self.hexEdit = ColorConversionUtils.colorToHex(newValue) ?? "failed"

            //            log("StitchColorPickerView: onChange of self.chosenColor: hexEdit is now: \(self.hexEdit)")
        }
    }

    // -- MARK: HEX CODE INPUT FIELD

    var hexEditAndDisplay: some View {
        HStack {
            Text("Hex: ")
            hextTextField
        }
        .frame(width: 150)
    }

    @State var hexEdit = ""
    @FocusState var hexFocus: Bool

    // changed whenever we copy-paste a hex or select a color-grid item;
    // manual control of re-rendering
    @State var sliderId = UUID()

    var hextTextField: some View {
        TextField(chosenColor.asHexDisplay,
                  text: self.$hexEdit)
            //            .focused($hexFocus) // not needed?
        
        .focusedValue(\.focusedField, .textInput(fieldCoordinate))
        
            .onSubmit {
                //                log("StitchColorPickerView: onSubmit: self.hexEdit: \(self.hexEdit)")
                // invalid edits are coerced to "white"
                //                self.chosenColor = Color.init(hex: self.hexEdit)
                self.chosenColor = ColorConversionUtils.hexToColor(self.hexEdit) ?? .black
                self.sliderId = .init()
            }
            .background(Color.gray.opacity(0.5))
            .frame(width: 90)
            .fixedSize(horizontal: true, vertical: false)
    }

    // -- MARK: HSLA SLIDERS

    var sliders: some View {
        HStack(alignment: .center) {
            HueSliderView(chosenColor: $chosenColor, 
                          graph: graph)
            Spacer()
            SaturationSliderView(chosenColor: $chosenColor, 
                                 graph: graph)
            Spacer()
            LightnessSliderView(chosenColor: $chosenColor,
                                graph: graph)

            // Do not allow alpha adjustments for preview window's background color
            if !isForPreviewWindowBackgroundPicker {
                Spacer()
                AlphaSliderView(chosenColor: $chosenColor,
                                graph: graph)
            }
            //            Spacer()
            //            AlphaSliderView(chosenColor: $chosenColor)
        }
        .frame(width: 150)
        .id(sliderId)
    }

    // -- MARK: COLOR CIRCLE GRID

    // https://developer.apple.com/documentation/swiftui/grid

    func suggestedColorsArray() -> [Color] {
        [
            .red, .orange, .yellow
            , .green, .cyan, .blue
            , .teal, .indigo, .purple
            , .black, .gray, .white
        ]

        ////  Alternatively, adjusting current hue's alpha:
        //        let rgba = self.currentColor.asRGBA
        //        var colors = [Color]()
        //        (0..<9).forEach { index in
        //            let alpha = rgba.alpha * CGFloat((Double(index) * 0.1))
        //            let color = Color.init(
        //                rgba: .init(red: rgba.red,
        //                            green: rgba.green,
        //                            blue: rgba.blue,
        //                            alpha: alpha))
        //            colors.append(color)
        //        }
        //        return colors

    }

    @MainActor
    func colorGridItem(_ color: Color) -> some View {
        Circle().fill(color)
            //            .stroke(.black)
            .frame(width: 50)
            .modifier(ColorOrbWrapperModifier())
            .onTapGesture {

                // When user manually clicks a pre-selected color,
                // we should persist that change.
                if let inputId = rowId,
                   self.chosenColor.asHexDisplay != color.asHexDisplay {
                    dispatch(PickerOptionSelected(
                        input: inputId,
                        choice: .color(color), 
                        isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                        // Lots of small changes so don't persist everything
                        isPersistence: true))
                }

                self.chosenColor = color
                self.hexEdit = color.asHexDisplay
                self.sliderId = .init()
            }
    }

    @MainActor
    var colorGrid: some View {

        let colors = suggestedColorsArray()

        return Grid(alignment: .center) {

            GridRow(alignment: .center) {
                ForEach(0..<4) {
                    colorGridItem(colors[$0])
                }
            }
            GridRow(alignment: .center) {
                ForEach(4..<8) {
                    colorGridItem(colors[$0])
                }
            }

            GridRow(alignment: .center) {
                ForEach(8..<12) {
                    colorGridItem(colors[$0])
                }
            }
        }
    }
}

//#Preview {
//    
//    VStack(spacing: 100) {
//        
//        StitchColorPickerOrb(chosenColor: .green)
//            .scaleEffect(2)
//        
//        StitchColorPickerView(coordinate: .fakeInputCoordinate,
//                              chosenColor: .constant(.red),
//                              graph: .init(id: .init(), store: nil))
//            .scaleEffect(2)
//    }
//    
//}

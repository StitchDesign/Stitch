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
    let layerInputObserver: LayerInputObserver?
    let fieldCoordinate: FieldCoordinate
    let isFieldInsideLayerInspector: Bool
    let isForFlyout: Bool
    var isForPreviewWindowBackgroundPicker: Bool = false
    var isForIPhone: Bool = false

    //    @State var currentColor: Color = .clear
    //    @State var chosenColor: Color = .red
    @Binding var chosenColor: Color
    let graph: GraphState
        
#if targetEnvironment(macCatalyst)
    let isCatalyst: Bool = true
#else
    let isCatalyst: Bool = false
#endif
    
    @MainActor
    var isMultiselectInspectorInputWithHeterogenousValues: Bool {
        if let layerInputObserver = layerInputObserver {
            @Bindable var layerInputObserver = layerInputObserver
            return layerInputObserver.fieldHasHeterogenousValues(
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
                    StitchCustomColorPickerView(
                        rowId: rowId,
                        fieldCoordinate: fieldCoordinate,
                        isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                        isForPreviewWindowBackgroundPicker: isForPreviewWindowBackgroundPicker,
                        isForIPhone: isForIPhone,
                        chosenColor: self.$chosenColor,
                        graph: graph)
                    .padding()
                    
                })
                .onTapGesture {
//                    if !isCatalyst && isForFlyout {
                    
                    // iPad layer inspector uses flyout, due to iPad-platform-specifci shrinking
                    if !isCatalyst,
                       // isForFlyout, // TODO: always false?
                       isFieldInsideLayerInspector,
                       !isForPreviewWindowBackgroundPicker,
                       !isForIPhone,
                       let layerInputObserver = layerInputObserver,
                       let nodeId = rowId?.nodeId {
                        // iPad
                        dispatch(FlyoutToggled(flyoutInput: layerInputObserver.port,
                                               flyoutNodeId: nodeId,
                                               fieldToFocus: nil))
                    } else {
                        show.toggle()
                    }
                    
                }
        } // ZStack
    }

    var debugColorCircle: some View {
        Circle().fill(chosenColor)
            .stroke(.black)
            .frame(width: 60)
            .padding()
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

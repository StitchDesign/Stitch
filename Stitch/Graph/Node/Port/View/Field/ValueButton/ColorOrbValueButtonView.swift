//
//  ColorOrbValueButton.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/7/22.
//

import SwiftUI
import StitchSchemaKit

struct ColorOrbValueButtonView: View {
    @State private var colorState: Color = .white

    let fieldViewModel: InputFieldViewModel
        
    let rowObserver: InputNodeRowObserver
    
    let rowId: NodeRowViewModelId
    let isForLayerInspector: Bool
    
    let isForFlyout: Bool
    let currentColor: Color // the current color, from input
    let hasIncomingEdge: Bool
    let graph: GraphState
    let isMultiselectInspectorInputWithHeterogenousValues: Bool
    let activeIndex: ActiveIndex
    
    var body: some View {

        // logInView("ColorOrbValueButtonView: body: currentColor.asHexDisplay: \(currentColor.asHexDisplay)")
        // logInView("ColorOrbValueButtonView: body: self.colorState.asHexDisplay: \(self.colorState.asHexDisplay)")

        let binding = Binding<Color>.init {
            // log("ColorOrbValueButtonView: binding: get: self.colorState: \(self.colorState.asHexDisplay)")
            return self.colorState
        } set: { newColor in
            // log("ColorOrbValueButtonView: binding: set: newColor: \(newColor.asHexDisplay)")
            // log("ColorOrbValueButtonView: binding: set: currentColor: \(currentColor.asHexDisplay)")
            self.colorState = newColor

            // Must compare the strings
            if currentColor.asHexDisplay != self.colorState.asHexDisplay {
                graph.pickerOptionSelected(
                    rowObserver: rowObserver,
                    choice: .color(newColor),
                    activeIndex: activeIndex,
                    isFieldInsideLayerInspector: isForLayerInspector,
                    // Lots of small changes so don't persist everything
                    isPersistence: false)
            }
        }

        StitchColorPickerView(rowViewModelId: rowId,
                              rowObserver: rowObserver,
                              fieldCoordinate: fieldViewModel.id,
                              isFieldInsideLayerInspector: isForLayerInspector,
                              isForFlyout: isForFlyout,
                              isMultiselectInspectorInputWithHeterogenousValues: isMultiselectInspectorInputWithHeterogenousValues,
                              activeIndex: activeIndex,
                              chosenColor: binding,
                              graph: graph)
        .onAppear {
            self.colorState = currentColor
        }
            //            .id(self.viewId)
            // ^^ this might be happening too late?
            // better to set via `.init` ?

            /*
             Any non-manual color change (e.g. new currentColor coming in from node eval or edge),
             we want to change the colors.

             NOTE: I would expect changing the local colorState to be enough to update the SwiftUI ColorPicker's color; but apparently we must force a re-render.
             */
            // TODO: not needed anymore?
            .onChange(of: currentColor) { _, newColor in
                //            .onChange(of: currentColor, initial: true) { oldColor, newColor in
                // log("ColorOrbValueButtonView: onChange of currentColor: oldColor.asHexDisplay: \(oldColor.asHexDisplay)")
                // log("ColorOrbValueButtonView: onChange of currentColor: newColor.asHexDisplay: \(newColor.asHexDisplay)")
                //                if hasIncomingEdge {
                // log("ColorOrbValueButtonView: onChange of currentColor: will update self.colorState")
                self.colorState = newColor
                //                }
            }
            .onChange(of: hasIncomingEdge) {
                // log("ColorOrbValueButtonView: onChange of hasIncomingEdge: self.colorState.asHexDisplay: \(self.colorState.asHexDisplay)")
                // log("ColorOrbValueButtonView: onChange of hasIncomingEdge: currentColor.asHexDisplay: \(currentColor.asHexDisplay)")
                self.colorState = currentColor
            }
    }
}

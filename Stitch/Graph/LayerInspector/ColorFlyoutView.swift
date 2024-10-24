//
//  ColorFlyoutView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/24/24.
//

import SwiftUI

extension LayerInputPort {
    var usesColor: Bool {
        // NOTE: `for: Layer` only matters size input
        self.getDefaultValue(for: .rectangle).getColor.isDefined
    }
}

// Color is always .packed
struct ColorFlyoutView: View {
    
    @State var height: CGFloat? = nil
    
    @Bindable var graph: GraphState
    
    let layerInputObserver: LayerInputObserver
    let nodeId: NodeId
    
    @State var chosenColor: Color = .white

    var activeColor: Color {
        if let color = layerInputObserver.activeValue.getColor {
            return color
        } else {
            fatalErrorIfDebug()
            return .clear
        }
    }
    
    var body: some View {
        if let fieldObserver = layerInputObserver.fieldValueTypes.first?.fieldObservers.first,
           let rowId = fieldObserver.rowDelegate?.id {
            
            StitchCustomColorPickerView(
                rowId: rowId,
                fieldCoordinate: fieldObserver.id,
                isFieldInsideLayerInspector: true, // true for purposes of editing multiple layers
                isForPreviewWindowBackgroundPicker: false,
                isForIPhone: false,
                // i.e. the current active value
                chosenColor: self.$chosenColor,
                graph: graph)
            .modifier(FlyoutBackgroundColorModifier(
                width: nil, // rely on default width from color picker
                height: self.$height))
            .onAppear(perform: {
                self.chosenColor = activeColor
            })
            .onChange(of: self.chosenColor) { oldColor, newColor in
                dispatch(PickerOptionSelected(
                    input: rowId,
                    choice: .color(newColor),
                    isFieldInsideLayerInspector: true,
                    // Lots of small changes so don't persist everything
                    isPersistence: false))
            }
            
        }
    }
}

//
//  NumberValueButton.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/7/22.
//

import SwiftUI
import StitchSchemaKit

struct FieldButtonImage: View {
    
    @Environment(\.appTheme) var theme
    
    let sfSymbolName: String
    let isSelectedInspectorRow: Bool
    
    var body: some View {
        Image(systemName: sfSymbolName)
            // Do not .scaleToFit (?) the adjustment bar button, since it can become very small on some nodes.
            // Better?: manually set a .frame
            //            .resizable()
            //            .scaledToFit()
            .foregroundColor(isSelectedInspectorRow ? theme.fontColor : VALUE_FIELD_BODY_COLOR)
    }
}

typealias AdjustmentBarSessionId = UUID

struct NumberValueButtonView: View {
    
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    let value: Double
    let fieldCoordinate: FieldCoordinate
    let rowObserver: InputNodeRowObserver
    let fieldValueNumberType: FieldValueNumberType
    let isFieldInsideLayerInspector: Bool
    let isSelectedInspectorRow: Bool
    
    @Binding var isPressed: Bool

    var body: some View {

        FieldButtonImage(sfSymbolName: "ellipsis.circle",
                         isSelectedInspectorRow: isSelectedInspectorRow)
            .rotationEffect(Angle(degrees: 90))
            .onTapGesture {
                self.isPressed = true
            }
            .onChange(of: graphUI.adjustmentBarSessionId) {
                // `AdjustmentBarSessionId` is changed just when
                self.isPressed = false
            }
            // TODO: add attachment anchor as well?
            .modifier(AdjustmentBarViewModifier(
                graph: graph,
                numberValue: value,
                fieldCoordinate: fieldCoordinate,
                rowObserver: rowObserver,
                isPressed: $isPressed,
                fieldValueNumberType: fieldValueNumberType,
                isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                activeIndex: graphUI.activeIndex))
    }
}

struct AdjustmentBarViewModifier: ViewModifier {
    @Bindable var graph: GraphState
    let numberValue: Double
    let fieldCoordinate: FieldCoordinate
    let rowObserver: InputNodeRowObserver
    @Binding var isPressed: Bool
    let fieldValueNumberType: FieldValueNumberType
    let isFieldInsideLayerInspector: Bool
    let activeIndex: ActiveIndex

    func body(content: Content) -> some View {
        return content
            // TODO: add attachment anchor as well?
            .popover(isPresented: $isPressed, arrowEdge: .top) {
                AdjustmentBarPopoverView(
                    // current number, always update to date,
                    // from redux
                    graph: graph,
                    stateNumber: numberValue,
                    fieldValueNumberType: fieldValueNumberType,
                    fieldCoordinate: fieldCoordinate,
                    rowObserver: rowObserver,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    activeIndex: activeIndex,
                    isPopoverOpen: self.$isPressed
                )
                #if !targetEnvironment(macCatalyst)
                .background {
                // https://marcpalmer.net/colouring-the-arrow-of-a-popover-in-swiftui/
                ADJUSTMENT_BAR_POPOVER_BACKGROUND_COLOR
                .padding(-80)
                }
                #endif
            } // .popover
    }
}

// TODO: resurrect
// struct NumberValueButton_Previews: PreviewProvider {
//    static var previews: some View {
//        NumberValueButtonView(fieldCoordinate: .fakeFieldCoordinate) //, editType: .fakeMulti)
//            .environmentObject(AdjustmentBarObserver())
//    }
// }

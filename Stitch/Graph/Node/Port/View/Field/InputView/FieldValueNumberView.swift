//
//  FieldValueNumberView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/30/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct FieldValueNumberView: View {
    
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    @Bindable var rowObserver: InputNodeRowObserver
    @Bindable var rowViewModel: InputNodeRowViewModel
    @Bindable var fieldViewModel: InputFieldViewModel
    let layerInputObserver: LayerInputObserver?
    let fieldValue: FieldValue
    let fieldValueNumberType: FieldValueNumberType
    let fieldCoordinate: FieldCoordinate
    let isCanvasItemSelected: Bool
    let choices: [String]?
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isFieldInMultifieldInput: Bool
    let isForFlyout: Bool
    let isSelectedInspectorRow: Bool
    var isForSpacingField: Bool = false
    var isForLayerDimensionField: Bool = false
    var nodeKind: NodeKind
    
    @State private var isButtonPressed = false
    
    var fieldIndex: Int {
        self.fieldViewModel.fieldIndex
    }
    
    var isFieldInMultifieldInputInInspector: Bool {
        isFieldInMultifieldInput && forPropertySidebar && !isForFlyout
    }
    
    var body: some View {
        
        HStack {
            
            // Do not show number adjustment bar if field is part of a multifield input inside the layer inspector
            if !isFieldInMultifieldInputInInspector {
                
                // Default to zero if "auto" currently selected
                // Limit renders by not passing in number value unless button pressed
                NumberValueButtonView(graph: graph,
                                      graphUI: graphUI,
                                      value: isButtonPressed ? fieldValue.numberValue : .zero,
                                      fieldCoordinate: fieldCoordinate,
                                      rowObserver: rowObserver,
                                      fieldValueNumberType: fieldValueNumberType,
                                      isFieldInsideLayerInspector: rowViewModel.isFieldInsideLayerInspector,
                                      isSelectedInspectorRow: isSelectedInspectorRow,
                                      isPressed: $isButtonPressed)
            }
            
            CommonEditingViewWrapper(graph: graph,
                                     graphUI: graphUI,
                                     fieldViewModel: fieldViewModel,
                                     rowObserver: rowObserver,
                                     rowViewModel: rowViewModel,
                                     layerInputObserver: layerInputObserver,
                                     fieldValue: fieldValue,
                                     fieldCoordinate: fieldCoordinate,
                                     isCanvasItemSelected: isCanvasItemSelected,
                                     choices: choices,
                                     forPropertySidebar: forPropertySidebar,
                                     propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                     isFieldInMultifieldInput: isFieldInMultifieldInput,
                                     isForFlyout: isForFlyout, 
                                     isSelectedInspectorRow: isSelectedInspectorRow,
                                     isForLayerDimensionField: isForLayerDimensionField,
                                     nodeKind: nodeKind)
        }
    }
}

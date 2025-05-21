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
    @Bindable var document: StitchDocumentViewModel
    @Bindable var rowObserver: InputNodeRowObserver
        
    @Bindable var inputField: InputFieldViewModel
    
    let fieldValueNumberType: FieldValueNumberType
    
    let layerInput: LayerInputPort?
    
    let choices: [String]?
    
    let isForLayerInspector: Bool
    let hasHeterogenousValues: Bool
    let isPackedLayerInputAlreadyOnCanvas: Bool
    
    let isFieldInMultifieldInput: Bool
    
    let isForFlyout: Bool
    let isSelectedInspectorRow: Bool
    
    var isForSpacingField: Bool = false
    var isForLayerDimensionField: Bool = false
    
    var nodeKind: NodeKind
    
    @State private var isButtonPressed = false
        
    var isFieldInMultifieldInputInInspector: Bool {
        isFieldInMultifieldInput && isForLayerInspector && !isForFlyout
    }
    
    var body: some View {
        
        HStack {
            
            // Do not show number adjustment bar if field is part of a multifield input inside the layer inspector
            if !isFieldInMultifieldInputInInspector {
                
                // Default to zero if "auto" currently selected
                // Limit renders by not passing in number value unless button pressed
                NumberValueButtonView(graph: graph,
                                      document: document,
                                      value: isButtonPressed ? inputField.fieldValue.numberValue : .zero,
                                      fieldCoordinate: inputField.id,
                                      rowObserver: rowObserver,
                                      fieldValueNumberType: fieldValueNumberType,
                                      isFieldInsideLayerInspector: isForLayerInspector,
                                      isSelectedInspectorRow: isSelectedInspectorRow,
                                      isPressed: $isButtonPressed)
            }
            
            CommonEditingView(document: document,
                                     inputField: inputField,
                                     layerInput: layerInput,
                                     choices: choices,
                                     // TODO: was not being used?
                                     isLargeString: false,
                                     isForLayerInspector: isForLayerInspector,
                                     isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                                     hasHeterogenousValues: hasHeterogenousValues,
                                     isFieldInMultifieldInput: isFieldInMultifieldInput,
                                     isForFlyout: isForFlyout, 
                                     usesThemeColor: isSelectedInspectorRow,
                                     isForLayerDimensionField: isForLayerDimensionField,
                                     nodeKind: nodeKind)
        }
    }
}

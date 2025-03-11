//
//  LayerInspector3DTransformInputView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/11/25.
//

import SwiftUI

// 3D Transform, 3D Size etc.
struct LayerInspector3DTransformInputView: View {
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let layerInputObserver: LayerInputObserver
    
    var body: some View {
        VStack {
            ForEach(layerInputObserver.fieldValueTypes) { fieldGrouping in
                VStack {
                    if let fieldGroupLabel = fieldGrouping.groupLabel {
                        HStack {
                            LabelDisplayView(label: fieldGroupLabel,
                                             isLeftAligned: false,
                                             fontColor: STITCH_FONT_GRAY_COLOR,
                                             isSelectedInspectorRow: false)
                            Spacer()
                        }
                    }
                    
                    HStack {
                        self.observerViews(fieldGrouping.fieldObservers)
                    }
                }
            } // ForEach
        }
    }
    
    // Note: 3D Transform inputs can never be "blocked"; revisit this if that changes; would just pass down
    func observerViews(_ fieldObservers: [InputNodeRowViewModel.FieldType]) -> some View {
        
        ForEach(fieldObservers) { fieldObserver  in
            
            HStack {
                LabelDisplayView(label: fieldObserver.fieldLabel,
                                 isLeftAligned: true,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 // TODO: MARCH 10: for font color when selected on iPad
                                 isSelectedInspectorRow: false)
                
                CommonEditingViewReadOnly(
                    inputField: fieldObserver,
                    inputString: fieldObserver.fieldValue.stringValue,
                    forPropertySidebar: true,
                    isHovering: false, // Can never hover on a inspector's multifield
                    choices: nil, // always nil for layer dropdown ?
                    fieldWidth: INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH,
                    
                    // TODO: MARCH 10: easier way to tell if part of heterogenous layer multiselect
                    fieldHasHeterogenousValues: false,
                    
                    // TODO: MARCH 10: for font color when selected on iPad
                    isSelectedInspectorRow: false,
                    
                    isFieldInMultfieldInspectorInput: true) {
                        // If entire packed input is already on canvas, we should jump to that input on that canvas rather than open the flyout
                        if layerInputObserver.mode == .packed,
                           let canvasNodeForPackedInput = layerInputObserver.getCanvasItemForWholeInput() {
                            log("LayerInspector3DTransformInputView: will jump to canvas for \(layerInputObserver.port)")
                            graph.jumpToCanvasItem(id: canvasNodeForPackedInput.id,
                                                   document: document)
                        } else {
                            log("LayerInspector3DTransformInputView: will open flyout for \(layerInputObserver.port)")
                            dispatch(FlyoutToggled(
                                flyoutInput: layerInputObserver.port,
                                flyoutNodeId: self.node.id,
                                fieldToFocus: .textInput(fieldObserver.id)))
                        }
                    }
            }
        } // ForEach
    }
}

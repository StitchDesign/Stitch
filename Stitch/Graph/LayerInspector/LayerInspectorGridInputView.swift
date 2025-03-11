//
//  LayerInspectorGridInputView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/11/25.
//

import SwiftUI

struct LayerInspectorGridInputView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let layerInputObserver: LayerInputObserver
    
    
    var allFieldObservers: [InputNodeRowViewModel.FieldType] {
        layerInputObserver.fieldValueTypes.flatMap(\.fieldObservers)
    }
    
    var overallLabel: String {
        layerInputObserver.overallPortLabel(usesShortLabel: true, node: node, graph: graph)
    }
    
    var body: some View {
                        
        // Aligns fields with "padding" label's text baseline
        HStack(alignment: .firstTextBaseline) {
            
            // Label
            LabelDisplayView(label: overallLabel,
                             isLeftAligned: false,
                             fontColor: STITCH_FONT_GRAY_COLOR,
                             isSelectedInspectorRow: false)
            
            Spacer()
            
            if let p0 = allFieldObservers[safe: 0],
               let p1 = allFieldObservers[safe: 1],
               let p2 = allFieldObservers[safe: 2],
               let p3 = allFieldObservers[safe: 3] {
                
                // Pseudo grid
                VStack {
                    HStack {
                        self.observerView(p0)
                        self.observerView(p1)
                    }
                    HStack {
                        self.observerView(p2)
                        self.observerView(p3)
                    }
                }
            } else {
                EmptyView().onAppear { fatalErrorIfDebug() }
            }
        }
        // TODO: `LayerInspectorPortView`'s `.listRowInsets` should maintain consistent padding between input-rows in the layer inspector, so why is additional padding needed?
        .padding(.vertical, INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET * 2)
    }
    
    
    // Note: a layer's padding and margin inputs/fields can never be blocked; we can revisit this if that changes in the future
    func observerView(_ fieldObserver: InputNodeRowViewModel.FieldType) -> some View {
        
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
                    log("LayerInspectorGridView: will jump to canvas for \(layerInputObserver.port)")
                    graph.jumpToCanvasItem(id: canvasNodeForPackedInput.id,
                                           document: document)
                } else {
                    log("LayerInspectorGridView: will open flyout for \(layerInputObserver.port)")
                    dispatch(FlyoutToggled(
                        flyoutInput: layerInputObserver.port,
                        flyoutNodeId: self.node.id,
                        fieldToFocus: .textInput(fieldObserver.id)))
                }
            }
    }
}

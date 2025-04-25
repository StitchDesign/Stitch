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
    let isPropertyRowSelected: Bool
    
    var allFieldObservers: [FieldViewModel] {
        layerInputObserver.fieldValueTypes.flatMap(\.fieldObservers)
    }
    
    var body: some View {
                        
        // Aligns fields with "padding" label's text baseline
        HStack(alignment: .firstTextBaseline) {
            
            // Label
            LabelDisplayView(label: layerInputObserver.overallPortLabel(usesShortLabel: true),
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
    func observerView(_ fieldObserver: FieldViewModel) -> some View {
        LayerInspectorReadOnlyView(propertySidebar: graph.propertySidebar,
                                   nodeId: node.id,
                                   layerInputObserver: layerInputObserver,
                                   fieldObserver: fieldObserver,
                                   isPropertyRowSelected: isPropertyRowSelected)
    }
}


// Only used by inspector's special multifield views
struct LayerInspectorReadOnlyView: View {
    @Bindable var propertySidebar: PropertySidebarObserver
    let nodeId: NodeId
    let layerInputObserver: LayerInputObserver
    let fieldObserver: FieldViewModel
    let isPropertyRowSelected: Bool
    
    // TODO: is `InputFieldValueView` ever used in the layer inspector now? ... vs flyout?
    @MainActor
    var hasHeterogenousValues: Bool {
        return propertySidebar.heterogenousFieldsMap?
            .get(layerInputObserver.port)?
            .contains(fieldObserver.fieldIndex) ?? false
    }
    
    var body: some View {
        CommonEditingViewReadOnly(
            inputField: fieldObserver,
            inputString: fieldObserver.fieldValue.stringValue,
            forPropertySidebar: true,
            isHovering: false, // Can never hover on a inspector's multifield
            choices: nil, // always nil for layer dropdown ?
            fieldWidth: INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH,
            fieldHasHeterogenousValues: hasHeterogenousValues,
            isSelectedInspectorRow: isPropertyRowSelected,
            isFieldInMultfieldInspectorInput: true) {
                // If entire packed input is already on canvas, we should jump to that input on that canvas rather than open the flyout
                if layerInputObserver.mode == .packed,
                   let canvasNodeForPackedInput = layerInputObserver.getCanvasItemForWholeInput() {
                    log("LayerInspectorGridView: will jump to canvas for \(layerInputObserver.port)")
                    dispatch(JumpToCanvasItem(id: canvasNodeForPackedInput.id))
                } else {
                    log("LayerInspectorGridView: will open flyout for \(layerInputObserver.port)")
                    dispatch(FlyoutToggled(
                        flyoutInput: layerInputObserver.port,
                        flyoutNodeId: nodeId,
                        fieldToFocus: .textInput(fieldObserver.id)))
                }
            }
    }
}

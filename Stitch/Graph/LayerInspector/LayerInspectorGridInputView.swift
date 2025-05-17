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
    let isSelectedInspectorRow: Bool
    
    var allFieldObservers: [FieldViewModel] {
        layerInputObserver.fieldGroupsFromInspectorRowViewModels.flatMap(\.fieldObservers)
    }
    
    // Use theme color if entire inspector input/output-row is selected,
    // or if this specific field is 'eligible' via drag-output.
    func usesThemeColor(_ field: InputFieldViewModel) -> Bool {
        isSelectedInspectorRow ||
        field.isEligibleForEdgeConnection(input: layerInputObserver.port,
                                          graph.edgeDrawingObserver)
    }
        
    var body: some View {
                        
        // Aligns fields with "padding" label's text baseline
        HStack(alignment: .firstTextBaseline) {
            
            // Label
            LabelDisplayView(label: layerInputObserver.overallPortLabel(usesShortLabel: true),
                             isLeftAligned: false,
                             fontColor: STITCH_FONT_GRAY_COLOR,
                             usesThemeColor: isSelectedInspectorRow)
            
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
        InspectorFieldReadOnlyView(propertySidebar: graph.propertySidebar,
                                   nodeId: node.id,
                                   layerInputObserver: layerInputObserver,
                                   fieldObserver: fieldObserver,
                                   usesThemeColor: usesThemeColor(fieldObserver))
        .modifier(
            TrackInspectorField(
                layerInputObserver: layerInputObserver,
                layerInputType: .init(
                    layerInput: layerInputObserver.port,
                    portType: .unpacked(fieldObserver.fieldIndex.asUnpackedPortType)),
                hasActivelyDrawnEdge: graph.edgeDrawingObserver.drawingGesture.isDefined)
        )
    }
}


// ONLY used by inspector's special multifield views, e.g. fields for Padding input
struct InspectorFieldReadOnlyView: View {
    @Bindable var propertySidebar: PropertySidebarObserver
    let nodeId: NodeId
    let layerInputObserver: LayerInputObserver
    let fieldObserver: FieldViewModel
    let usesThemeColor: Bool
    
    // TODO: is `InputFieldValueView` ever used in the layer inspector now? ... vs flyout?
    @MainActor
    var hasHeterogenousValues: Bool {
        return propertySidebar.heterogenousFieldsMap?
            .get(layerInputObserver.port)?
            .contains(fieldObserver.fieldIndex) ?? false
    }
    
    var body: some View {
        TapToEditReadOnlyView(
            inputString: fieldObserver.fieldValue.stringValue,
            fieldWidth: INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH,
            isFocused: false, // never true?
            isHovering: false,  // Can never hover on a inspector's multifield
            isForLayerInspector: true,
            hasPicker: false,
            fieldHasHeterogenousValues: hasHeterogenousValues,
            usesThemeColor: usesThemeColor,
            onTap: {
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
            })
    }
}

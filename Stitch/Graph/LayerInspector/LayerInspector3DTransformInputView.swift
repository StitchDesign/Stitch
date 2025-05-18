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
    let nodeId: NodeId
    let layerInputObserver: LayerInputObserver
    let isSelectedInspectorRow: Bool
    
    // Use theme color if entire inspector input/output-row is selected,
    // or if this specific field is 'eligible' via drag-output.
    func usesThemeColor(_ field: InputFieldViewModel) -> Bool {
        isSelectedInspectorRow ||
        field.isEligibleForEdgeConnection(input: layerInputObserver.port,
                                          graph.edgeDrawingObserver)
    }
    
    var body: some View {
        VStack {
            ForEach(layerInputObserver.fieldGroupsFromInspectorRowViewModels) { fieldGrouping in
                VStack {
                    if let fieldGroupLabel = fieldGrouping.groupLabel {
                        HStack {
                            LabelDisplayView(label: fieldGroupLabel,
                                             isLeftAligned: false,
                                             fontColor: STITCH_FONT_GRAY_COLOR,
                                             usesThemeColor: isSelectedInspectorRow)
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
    func observerViews(_ fieldObservers: [FieldViewModel]) -> some View {
        
        ForEach(fieldObservers) { fieldObserver  in

            let usesThemeColor = usesThemeColor(fieldObserver)
            
            HStack {
                LabelDisplayView(label: fieldObserver.fieldLabel,
                                 isLeftAligned: true,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 usesThemeColor: usesThemeColor)
                
                InspectorFieldReadOnlyView(propertySidebar: graph.propertySidebar,
                                           nodeId: nodeId,
                                           layerInputObserver: layerInputObserver,
                                           fieldObserver: fieldObserver,
                                           usesThemeColor: usesThemeColor)
            }
            .modifier(
                TrackInspectorField(
                    layerInputObserver: layerInputObserver,
                    layerInputType: .init(
                        layerInput: layerInputObserver.port,
                        portType: .unpacked(fieldObserver.fieldIndex.asUnpackedPortType)),
                    hasActivelyDrawnEdge: graph.edgeDrawingObserver.drawingGesture.isDefined)
            )
        } // ForEach
    }
}


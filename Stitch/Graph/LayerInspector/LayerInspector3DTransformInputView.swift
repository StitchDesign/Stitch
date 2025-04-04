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
    let isPropertyRowSelected: Bool
    
    var body: some View {
        VStack {
            ForEach(layerInputObserver.fieldValueTypes) { fieldGrouping in
                VStack {
                    if let fieldGroupLabel = fieldGrouping.groupLabel {
                        HStack {
                            LabelDisplayView(label: fieldGroupLabel,
                                             isLeftAligned: false,
                                             fontColor: STITCH_FONT_GRAY_COLOR,
                                             isSelectedInspectorRow: isPropertyRowSelected)
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
            
            HStack {
                LabelDisplayView(label: fieldObserver.fieldLabel,
                                 isLeftAligned: true,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 isSelectedInspectorRow: isPropertyRowSelected)
                
                LayerInspectorReadOnlyView(propertySidebar: graph.propertySidebar,
                                           nodeId: nodeId,
                                           layerInputObserver: layerInputObserver,
                                           fieldObserver: fieldObserver,
                                           isPropertyRowSelected: isPropertyRowSelected)
            }
        } // ForEach
    }
}


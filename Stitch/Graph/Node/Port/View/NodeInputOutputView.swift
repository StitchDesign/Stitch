//
//  NodeInputView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

/*
 Patch node input of Point4D = one node row observer becomes 4 fields
 
 Layer node input of Size = one node row observer becomes 1 single field
 */


struct ShadowInputInspectorRow: View {
    
    @Environment(\.appTheme) var theme
    
    let nodeId: NodeId
    let propertyIsSelected: Bool
    
    var body: some View {
        HStack {
            StitchTextView(string: "Shadow",
                           fontColor: propertyIsSelected ? theme.fontColor : STITCH_FONT_GRAY_COLOR)
            Spacer()
        }
        .overlay {
            Color.white.opacity(0.001)
                .onTapGesture {
                    dispatch(FlyoutToggled(
                        flyoutInput: SHADOW_FLYOUT_LAYER_INPUT_PROXY,
                        flyoutNodeId: nodeId,
                        // No particular field to focus
                        fieldToFocus: nil))
                }
        }
    }
}

struct NodeRowPortView<NodeRowObserverType: NodeRowObserver>: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var rowObserver: NodeRowObserverType
    @Bindable var rowViewModel: NodeRowObserverType.RowViewModelType
    
    @State private var showPopover: Bool = false
    
    var coordinate: NodeIOPortType {
        self.rowObserver.id.portType
    }
    
    var nodeIO: NodeIO {
        NodeRowObserverType.nodeIOType
    }
    
    // should be passed down as a param
    @MainActor
    var isGroup: Bool {
        node.kind.isGroup
    }
    
    var body: some View {
        PortEntryView(rowViewModel: rowViewModel,
                      graph: graph,
                      coordinate: coordinate)
        .onTapGesture {
            // Can only tap canvas ports, not layer inspector ports
            guard let canvasItemId = rowViewModel.canvasItemDelegate?.id else {
                return
            }

            // Do nothing when input/output doesn't contain a loop
            if rowObserver.hasLoopedValues {
                dispatch(PortPreviewOpened(port: self.rowObserver.id,
                                           nodeIO: nodeIO,
                                           canvasItemId: canvasItemId))
                
            }
        }
    }
}

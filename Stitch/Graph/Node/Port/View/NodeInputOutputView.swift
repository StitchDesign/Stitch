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

struct NodeRowPortView<NodeRowObserverType: NodeRowObserver>: View {
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var node: NodeViewModel
    @Bindable var rowObserver: NodeRowObserverType
    @Bindable var rowViewModel: NodeRowObserverType.RowViewModelType
    
    @State private var showPopover: Bool = false
    
    var nodeIO: NodeIO {
        NodeRowObserverType.nodeIOType
    }
        
    var body: some View {
        PortEntryView(portUIViewModel: rowViewModel.portUIViewModel,
                      graph: graph,
                      document: document,
                      rowId: rowViewModel.id,
                      nodeIO: nodeIO)
        .onTapGesture {
            // Can only tap canvas ports, not layer inspector ports
            guard let canvasItemId = rowViewModel.canvasItemDelegate?.id else {
                return
            }

            if nodeIO == .input {
                document.reduxFocusedField = .nodeInputPortSelection(rowViewModel.id)
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

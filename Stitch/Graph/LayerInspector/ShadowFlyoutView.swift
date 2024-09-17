//
//  ShadowFlyoutView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/17/24.
//

import SwiftUI
import StitchSchemaKit

// Represents "packed" shadow
let SHADOW_FLYOUT_LAYER_INPUT_PROXY = LayerInputPort.shadowColor

struct FlyoutHeader: View {
    
    let flyoutTitle: String
    
    var body: some View {
        HStack {
            StitchTextView(string: flyoutTitle).font(.title3)
            Spacer()
            Image(systemName: "xmark.circle.fill")
                .onTapGesture {
                    withAnimation {
                        dispatch(FlyoutClosed())
                    }
                }
        }
    }
}

struct ShadowFlyoutView: View {
    
    static let SHADOW_FLYOUT_WIDTH: CGFloat = 256.0
//    static let SHADOW_FLYOUT_HEIGHT = 200.0
    @State var height: CGFloat? = nil // 248.87 per GeometryReader measurements?
    
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    var body: some View {
        
        VStack(alignment: .leading) {
            FlyoutHeader(flyoutTitle: "Shadow")
            
            // TODO: why does UIKitWrapper mess up padding so badly?
//            UIKitWrapper(ignoresKeyCommands: false,
//                         name: "ShadowFlyout") {
                rows
//            }
//                         .border(.yellow)
//                         .padding()
//                         .border(.red)
        }
        .modifier(FlyoutBackgroundColorModifier(width: Self.SHADOW_FLYOUT_WIDTH,
                                                height: self.$height))
    }
    
    @MainActor
    var rows: some View {
        VStack(alignment: .leading,
               // TODO: why must we double this *and* use padding?
               spacing: INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET * 2) {
            ForEach(LayerInspectorView.shadow) { (shadowInput: LayerInputPort) in
                
                let layerInputPort: LayerInputObserver = layerNode[keyPath: shadowInput.layerNodeKeyPath]
                
                // Shadow input is *always packed*
                let layerInputData = layerInputPort._packedData
                                
                NodeInputView(graph: graph,
                              nodeId: node.id,
                              nodeKind: node.kind,
                              hasIncomingEdge: false,
                              rowObserverId: layerInputData.rowObserver.id,
                              rowObserver: nil,
                              rowViewModel: nil,
                              fieldValueTypes: layerInputData.inspectorRowViewModel.fieldValueTypes,
                              layerInputObserver: layerInputPort,
                              forPropertySidebar: true,
                              propertyIsSelected: false, // N/A ?
                              propertyIsAlreadyOnGraph: false,
                              isCanvasItemSelected: false,
                              label: layerInputData.rowObserver.label(true),
                              forFlyout: true)
                
                .padding([.top, .bottom], INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET * 2)
                
                .onChange(of: layerInputPort.mode) {
                    // Unpacked modes not supported here
                    assertInDebug(layerInputPort.mode == .packed)
                }
            }
        }
    }
}

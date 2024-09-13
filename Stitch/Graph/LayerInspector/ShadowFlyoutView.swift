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
    
    static let SHADOW_FLYOUT_WIDTH = 256.0
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
        .padding()
        .background(Color.WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE)
        .cornerRadius(8)
        .frame(width: Self.SHADOW_FLYOUT_WIDTH, 
//               height: Self.SHADOW_FLYOUT_HEIGHT)
               height: self.height)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .named(NodesView.coordinateNameSpace)),
                              initial: true) { oldValue, newValue in
                        log("Shadow flyout size: \(newValue.size)")
                        self.height = newValue.size.height
                        dispatch(UpdateFlyoutSize(size: newValue.size))
                    }
            }
        }
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
                              rowData: nil,
                              fieldValueTypes: layerInputData.inspectorRowViewModel.fieldValueTypes,
                              inputLayerNodeRowData: layerInputPort, // layerInputData, // not needed though?
                              forPropertySidebar: true,
                              propertyIsSelected: false, // N/A ?
                              propertyIsAlreadyOnGraph: false,
                              isCanvasItemSelected: false,
                              layerInput: nil, // only for layer inspector
                              label: layerInputData.rowObserver.label(true),
                              forFlyout: true)
//                .border(.green)
                
//                NodeInputView(graph: graph,
//                              rowObserver: layerInputData.rowObserver,
//                              rowData: layerInputData.inspectorRowViewModel,
//                              inputLayerNodeRowData: layerInputData,
//                              forPropertySidebar: true,
//                              propertyIsSelected: false, // NA
//                              // TODO: applicable or not?
//                              propertyIsAlreadyOnGraph: false ,
//                              isCanvasItemSelected: false,
//                              forFlyout: true)
                
                // Each row seems too tall? Probably from a set node row height somewhere?
                // Uses padding to reduce size
                .padding([.top, .bottom], INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET * 2)
//                .padding([.leading, .trailing], LAYER_INSPECTOR_ROW_SPACING)
////                .frame(height: 32) // per Figma // Doesn't work while a single row is split across a VStack
//                .background {
//                    WHITE_IN_LIGHT_MODE_GRAY_IN_DARK_MODE
//                        .cornerRadius(6)
//                }
                .onChange(of: layerInputPort.mode) {
                    // Unpacked modes not supported here
                    assertInDebug(layerInputPort.mode == .packed)
                }
            }
        }
    }
}

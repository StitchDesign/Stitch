//
//  ShadowFlyoutView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/17/24.
//

import SwiftUI
import StitchSchemaKit

// Represents "packed" shadow
let SHADOW_FLYOUT_LAYER_INPUT_PROXY = LayerInputType.shadowColor

struct ShadowFlyoutView: View {
    
    static let SHADOW_FLYOUT_WIDTH = 256.0
    static let SHADOW_FLYOUT_HEIGHT = 200.0
    
    @Bindable var node: NodeViewModel
    @Bindable var layerNode: LayerNodeViewModel
    @Bindable var graph: GraphState
    
    var body: some View {
        
        VStack(alignment: .leading) {
            HStack {
                StitchTextView(string: "Shadow").font(.title3)
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .onTapGesture {
                        withAnimation {
                            dispatch(FlyoutClosed())
                        }
                    }
            }
            
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
        .background(Color.SWIFTUI_LIST_BACKGROUND_COLOR)
        .cornerRadius(8)
        .frame(width: Self.SHADOW_FLYOUT_WIDTH, height: Self.SHADOW_FLYOUT_HEIGHT)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .named(NodesView.coordinateNameSpace)),
                              initial: true) { oldValue, newValue in
                        log("Shadow flyout size: \(newValue.size)")
                        dispatch(UpdateFlyoutSize(size: newValue.size))
                    }
            }
        }
    }
    
    @MainActor
    var rows: some View {
        VStack(alignment: .leading) {
            ForEach(LayerInspectorView.shadow) { shadowInput in
                let layerInputData = layerNode[keyPath: shadowInput.layerNodeKeyPath]
                NodeInputView(graph: graph,
                              rowObserver: layerInputData.rowObserver,
                              rowData: layerInputData.inspectorRowViewModel,
                              forPropertySidebar: true,
                              propertyIsSelected: false, // NA
                              // TODO: applicable or not?
                              propertyIsAlreadyOnGraph: false ,
                              isCanvasItemSelected: false)
            }
        }
//        .padding()
    }
    
    
}

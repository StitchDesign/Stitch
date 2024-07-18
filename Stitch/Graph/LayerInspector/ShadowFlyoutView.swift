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
        .background(Color.SWIFTUI_LIST_BACKGROUND_COLOR)
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

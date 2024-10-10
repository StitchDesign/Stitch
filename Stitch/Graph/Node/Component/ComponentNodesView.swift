//
//  ComponentNodesView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/9/24.
//

import SwiftUI

struct ComponentNodesView: View {
    let componentId: UUID
    let graph: GraphState
    
    var componentData: StitchComponent? {
        guard let componentDelegate = self.graph.documentEncoderDelegate as? ComponentEncoder else {
            return nil
        }
        
        return componentDelegate.lastEncodedDocument
    }

    func getLinkedSystemComponent(from componentData: StitchComponent) -> StitchComponent? {
        graph.storeDelegate?.systems.findSystem(forComponent: componentData.id)?
            .componentEncoders.get(componentData.id)?.lastEncodedDocument
    }
    
    func getSubheader(isLinkedToSystem: Bool) -> String {
        !isLinkedToSystem ? "Local Component" : "Linked Component"
    }
    
    var body: some View {
        if let componentData = componentData {
            let linkedComponentData = self.getLinkedSystemComponent(from: componentData)
            
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text(componentData.name)
                            .font(.headline)
                        Text(self.getSubheader(isLinkedToSystem: linkedComponentData != nil))
                            .font(.subheadline)
                    }
                    
                    if let linkedComponentData = linkedComponentData {
                        if linkedComponentData.componentHash != componentData.componentHash {
                            Text("Non-Equal")
                                .font(.callout)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Spacer()
            }
        } else {
            EmptyView()
        }
    }
}

//#Preview {
//    ComponentNodesView(
//        componentViewModel: .init(componentData: .init(),
//                                  parentGraph: nil),
//        graph: .createEmpty())
//}

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
    
    func getSubheader(from componentData: StitchComponent) -> String {
        switch componentData.saveLocation {
        case .localComponent:
            return "Local Component"
            
        case .systemComponent:
            return "Linked Component"
            
        default:
            fatalErrorIfDebug()
            return ""
        }
    }
    
    var body: some View {
        if let componentData = componentData {
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text(componentData.name)
                            .font(.headline)
                        Text(self.getSubheader(from: componentData))
                            .font(.subheadline)
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

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

    func getLinkedSystemComponentEncoder(from componentData: StitchComponent) -> ComponentEncoder? {
        graph.storeDelegate?.systems.findSystem(forComponent: componentData.id)?
            .componentEncoders.get(componentData.id)
    }
    
    func getSubheader(isLinkedToSystem: Bool) -> String {
        !isLinkedToSystem ? "Local Component" : "Linked Component"
    }
    
    var body: some View {
        if let componentData = componentData {
            let linkedComponentEncoder = self.getLinkedSystemComponentEncoder(from: componentData)
            
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text(componentData.name)
                            .font(.headline)
                        Text(self.getSubheader(isLinkedToSystem: linkedComponentEncoder != nil))
                            .font(.subheadline)
                    }
                    
                    
                    if let linkedComponentEncoder = linkedComponentEncoder {
                        let linkedComponentData = linkedComponentEncoder.lastEncodedDocument

                        Button {
                            
                        } label: {
                            Text("Unlink")
                        }
    
                        if linkedComponentData.componentHash != componentData.componentHash {
                            ComponentVersionControlButtons(linkedEncoder: linkedComponentEncoder,
                                                           componentGraph: graph)
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

struct ComponentVersionControlButtons: View {
    let linkedEncoder: ComponentEncoder
    let componentGraph: GraphState
    
    var body: some View {
        HStack {
            // Overwrite local changes to linked component
            Button {
                let newSchema = componentGraph.createSchema()
                var newComponentSchema = linkedEncoder.lastEncodedDocument
                newComponentSchema.graph = newSchema
                
                Task { [weak linkedEncoder] in
                    await linkedEncoder?.encodeProject(newComponentSchema)
                }

            } label: {
                Text("Publish")
            }

            // Reset local changes
            Button {
                let linkedComponent = linkedEncoder.lastEncodedDocument
                
                Task(priority: .high) { [weak componentGraph] in
                    await componentGraph?.update(from: linkedComponent.graph)
                    componentGraph?.encodeProjectInBackground()
                }
            } label: {
                Text("Reset")
            }
        }
    }
}

//#Preview {
//    ComponentNodesView(
//        componentViewModel: .init(componentData: .init(),
//                                  parentGraph: nil),
//        graph: .createEmpty())
//}

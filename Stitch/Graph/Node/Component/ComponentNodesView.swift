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
    
    func getLocalComponentEncoder() -> ComponentEncoder? {
        self.graph.documentEncoderDelegate as? ComponentEncoder
    }

    func getLinkedComponentEncoder(from componentData: StitchComponent) -> ComponentEncoder? {
        graph.storeDelegate?.systems.findSystem(forComponent: componentData.id)?
            .componentEncoders.get(componentData.id)
    }
    
    func getSubheader(isLinkedToSystem: Bool) -> String {
        !isLinkedToSystem ? "Local Component" : "Linked Component"
    }
    
    var body: some View {
        if let localComponentEncoder = self.getLocalComponentEncoder() {
            let localComponentData = localComponentEncoder.lastEncodedDocument
            let linkedComponentEncoder = self.getLinkedComponentEncoder(from: localComponentData)
            
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text(localComponentData.name)
                            .font(.headline)
                        Text(self.getSubheader(isLinkedToSystem: linkedComponentEncoder != nil))
                            .font(.subheadline)
                    }
                    
                    // Linked system component controls
                    if let linkedComponentEncoder = linkedComponentEncoder {
                        let linkedComponentData = linkedComponentEncoder.lastEncodedDocument

                        Button {
                            var localComponentData = localComponentData
                            localComponentData.graph.id = .init()
                            
                            Task(priority: .high) { [weak graph, weak localComponentEncoder] in
                                await graph?.update(from: localComponentData.graph)
                                localComponentEncoder?.encodeProjectInBackground(from: graph)
                            }
                            
                        } label: {
                            Text("Unlink")
                        }
    
                        if linkedComponentData.componentHash != localComponentData.componentHash {
                            ComponentVersionControlButtons(linkedEncoder: linkedComponentEncoder,
                                                           componentGraph: graph)
                        }
                    }
                    
                    // Unlinked component
                    else {
                        Button {
                            try? graph.storeDelegate?.saveComponentToUserLibrary(localComponentData)
                        } label: {
                            Text("Link to User Library")
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

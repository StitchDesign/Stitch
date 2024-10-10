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
    
    func getLocalComponent() -> StitchMasterComponent? {
        guard let componentEncoder = self.graph.documentEncoderDelegate as? ComponentEncoder else {
            return nil
        }
        
        return componentEncoder.delegate
    }

    func getLinkedComponent(from componentData: StitchComponent) -> StitchMasterComponent? {
        graph.storeDelegate?.systems.findSystem(forComponent: componentData.id)?
            .components.get(componentData.id)
    }
    
    func getSubheader(isLinkedToSystem: Bool) -> String {
        !isLinkedToSystem ? "Local Component" : "Linked Component"
    }
    
    var body: some View {
        if let localComponent = self.getLocalComponent() {
            let localComponentData = localComponent.lastEncodedDocument
            let linkedComponent = self.getLinkedComponent(from: localComponentData)
            
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text(localComponentData.name)
                            .font(.headline)
                        Text(self.getSubheader(isLinkedToSystem: linkedComponent != nil))
                            .font(.subheadline)
                    }
                    
                    // Linked system component controls
                    if let linkedComponent = linkedComponent {
                        let linkedComponentData = linkedComponent.lastEncodedDocument

                        Button {
                            let oldComponentUrl = localComponentData.rootUrl
                            
                            var localComponentData = localComponentData
                            localComponentData.graph.id = .init()
                            
                            Task(priority: .high) { [weak graph, weak localComponent] in
                                // Need to remove old draft component files
                                try? FileManager.default.removeItem(at: oldComponentUrl)
                                
                                await graph?.update(from: localComponentData.graph)
                                localComponent?.encoder.encodeProjectInBackground(from: graph)
                            }
                            
                        } label: {
                            Text("Unlink")
                        }
    
                        if linkedComponentData.componentHash != localComponentData.componentHash {
                            ComponentVersionControlButtons(linkedComponent: linkedComponent,
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
    let linkedComponent: StitchMasterComponent
    let componentGraph: GraphState
    
    var body: some View {
        HStack {
            // Overwrite local changes to linked component
            Button {
                let newSchema = componentGraph.createSchema()
                var newComponentSchema = linkedComponent.lastEncodedDocument
                newComponentSchema.graph = newSchema
                
                Task { [weak linkedComponent] in
                    await linkedComponent?.encoder.encodeProject(newComponentSchema)
                }

            } label: {
                Text("Publish")
            }

            // Reset local changes
            Button {
                let linkedComponent = linkedComponent.lastEncodedDocument
                
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

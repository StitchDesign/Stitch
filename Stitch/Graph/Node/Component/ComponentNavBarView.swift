//
//  ComponentNavBarView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/9/24.
//

import SwiftUI

struct ComponentNavBarView: View {
    @State private var linkedSystem: StitchSystemViewModel?
    
    @Bindable var graph: GraphState
    @Bindable var store: StitchStore
    
    var componentId: UUID {
        self.graph.id.value
    }
    
    func getLocalComponent() -> StitchMasterComponent? {
        guard let componentEncoder = self.graph.documentEncoderDelegate as? ComponentEncoder else {
            return nil
        }
        
        return componentEncoder.delegate
    }

    func getLinkedComponent(from componentData: StitchComponent) -> StitchMasterComponent? {
        store.systems.findSystem(forComponent: componentData.id)?
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
                        @Bindable var linkedComponent = linkedComponent
                        let linkedComponentData = linkedComponent.lastEncodedDocument

                        Button {
                            do {
                                try graph.documentDelegate?.unlinkComponent(localComponent: localComponent)
                            } catch {
                                log(error.localizedDescription)
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
                            try? store.saveComponentToUserLibrary(localComponentData)
                        } label: {
                            Text("Link to User Library")
                        }
                    }
                    
                    Spacer()
                    
                    Text("ID: \(componentId.debugFriendlyId)")
                        .font(.caption)
                        .monospaced()
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        } else {
            EmptyView()
        }
    }
}

// TODO: move
extension StitchDocumentViewModel {
    @MainActor
    func unlinkComponent(localComponent: StitchMasterComponent) throws {
        let localComponentData = localComponent.lastEncodedDocument
        let oldComponentUrl = localComponentData.rootUrl
        
        guard let documentUrl = self.documentEncoder?.rootUrl else {
            fatalErrorIfDebug()
            return
        }
        
        let newComponentData = try localComponentData.copyProject() { component in
            let newId = UUID()
            
            // Set new ID in save location, which determines URLs
            let _saveLocation = component.saveLocation.localComponentPath
            assertInDebug(_saveLocation != nil)
            var saveLocation = _saveLocation ?? GraphDocumentPath(docId: self.id.value,
                                                                  componentId: newId,
                                                                  componentsPath: [])
            
            saveLocation.componentId = newId
            
            component.saveLocation = .localComponent(saveLocation)
            component.graph.id = newId
        }
        
        // Delete old local component
        try? FileManager.default.removeItem(at: oldComponentUrl)
        
        let oldId = localComponentData.id
        let newId = newComponentData.id
        
        // Update all component nodes to use new ID
        self.changeComponentId(from: oldId,
                               to: newId)
        
        Task(priority: .high) { [weak self] in
            guard let document = self,
            let store = document.storeDelegate else {
                return
            }
            
            document.update(from: document.createSchema(),
                            rootUrl: documentUrl)
//            await document.updateAsync(from: document.createSchema())
            document.initializeDelegate(store: store)
            document.encodeProjectInBackground()
        }
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func changeComponentId(from: UUID, to: UUID) {
        // Change node data
        self.allComponents.forEach { componentNode in
            if componentNode.componentId == from {
                componentNode.componentId = to
                componentNode.graph.id = .init(to)
            }
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
                    guard let linkedComponent = linkedComponent else { return }
                    
                    guard let newSaveLocation = linkedComponent.encoder.saveLocation.documentSaveLocation else {
                        fatalErrorIfDebug()
                        return
                    }
                    
                    // Update save location of component to update url
                    newComponentSchema.saveLocation = newSaveLocation

                    let _ = await linkedComponent.encoder.encodeProject(newComponentSchema)
                }

            } label: {
                Text("Publish")
            }

            // Reset local changes
            Button {
                let linkedComponent = linkedComponent.lastEncodedDocument
                
                componentGraph.update(from: linkedComponent.graph,
                                      rootUrl: linkedComponent.rootUrl)
                componentGraph.encodeProjectInBackground()
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

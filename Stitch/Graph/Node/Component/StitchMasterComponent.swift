//
//  StitchMasterComponent.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/4/24.
//

import SwiftUI
import StitchSchemaKit

/// Tracks drafted and persisted versions of components, used to populate copies in graph.
final class StitchMasterComponent {
    @MainActor var componentData: StitchComponent {
        self.localComponentEncoder.lastEncodedDocument
    }
    
    let id: UUID
//    let saveLocation: GraphSaveLocation
    
    // Encoded copy of drafted component
    let localComponentEncoder: ComponentEncoder
    
    weak var parentGraph: GraphState?
    
    @MainActor
    init(componentData: StitchComponent,
         parentGraph: GraphState?) {
        self.id = componentData.id
//        self.saveLocation = componentData.saveLocation
        self.localComponentEncoder = .init(component: componentData)
        self.parentGraph = parentGraph
        
        if let parentGraph = parentGraph {
            self.initializeDelegate(parentGraph: parentGraph)
        }
    }
}

// TODO: move
extension [StitchSystemType: StitchSystemViewModel] {
    func findSystem(forComponent id: UUID) -> StitchSystemViewModel? {
        for system in self.values {
            if system.componentEncoders.get(id) != nil {
                return system
            }
        }
        
        return nil
    }
}

extension StitchStore {
    @MainActor func saveComponentToUserLibrary(_ component: StitchComponent) throws {
        guard let userSystem = self.systems.get(.userLibrary) else {
            let systemData = StitchSystem(id: .userLibrary,
                                          name: StitchSystemType.userLibraryName)
            
            do {
                try systemData.installDocument()
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
            }
            
            let userSystem = StitchSystemViewModel(data: systemData,
                                                   storeDelegate: self)
            // Save system to store
            self.systems.updateValue(userSystem, forKey: userSystem.data.id)
            
            try userSystem.data.saveComponentToSystem(component: component,
                                                      systemType: .userLibrary)
            return
        }
        
        try userSystem.data.saveComponentToSystem(component: component,
                                                  systemType: .userLibrary)
    }
}

extension StitchSystem {
    func saveComponentToSystem(component: StitchComponent,
                               systemType: StitchSystemType) throws {
        let srcUrl = component.rootUrl
        var newComponent = component
        newComponent.saveLocation = .systemComponent(systemType, component.id)
        try newComponent.encodeNewDocument(srcRootUrl: srcUrl)
    }
}

extension StitchMasterComponent {
    var publishedDocumentEncoder: ComponentEncoder? {
        guard let storeDelegate = self.storeDelegate else { return nil }
        
        for system in storeDelegate.systems.values {
            if let componentEncoder = system.componentEncoders.get(self.id) {
                return componentEncoder
            }
        }
        
        return nil
    }
    
//    @MainActor var publishedComponent: StitchComponent? {
//        self.componentData.published
//    }
//       
//    @MainActor var draftedComponent: StitchComponent {
//        self.componentData.draft
//    }
    
//    func update(from schema: StitchComponentData) {
//        self.componentData = schema
//    }
    
    @MainActor func createSchema(from graph: GraphState?) -> StitchComponent {
        guard let graph = graph?.createSchema() else {
            fatalErrorIfDebug()
            return .init()
        }
        
        var component = self.componentData
        component.graph = graph
        return component
    }
    
    static func createObject(from entity: StitchComponent) -> Self {
        fatalError()
//        .init(componentData: entity,
//              parentGraph: nil)
    }
    
    func onPrototypeRestart() { }
    
    @MainActor func initializeDelegate(parentGraph: GraphState) {
        self.parentGraph = parentGraph
        self.localComponentEncoder.delegate = self
    }
}

typealias MasterComponentsDict = [UUID : StitchMasterComponent]

extension MasterComponentsDict {
    @MainActor
    mutating func sync(with data: [StitchComponent],
                       parentGraph: GraphState) {
        self = self.sync(with: data,
                  updateCallback: { viewModel, data in
//            viewModel.update(from: data)
        }) { data in
            StitchMasterComponent(componentData: data,
                                  parentGraph: parentGraph)
        }
    }
}

extension StitchMasterComponent: DocumentEncodableDelegate, Identifiable {
    func willEncodeProject(schema: StitchComponent) {
        // Find all graphs using this component
        guard let graphs = self.parentGraph?.findComponentGraphStates(componentId: self.componentData.id) else {
            fatalErrorIfDebug()
            return
        }
        
        graphs.forEach { graph in
            Task(priority: .high) { [weak graph] in
                await graph?.update(from: schema.graph)
            }
        }
    }
    
    func updateOnUndo(schema: StitchComponent) {
        guard let document = self.parentGraph?.documentDelegate else {
            return
        }
        
        let componentId = self.id
        
        // Find all graph states using this component
        for component in document.allComponents {
            guard component.componentId == componentId else {
                continue
            }
            
            Task(priority: .high) { [weak component] in
                await component?.graph.update(from: schema.graph)
            }
        }
    }
    
    var storeDelegate: StoreDelegate? {
        self.parentGraph?.storeDelegate
    }
    
//    func importedFilesDirectoryReceived(mediaFiles: [URL],
//                                        components: [StitchComponentData]) {
//        guard let parentGraph = parentGraph else {
//            fatalErrorIfDebug()
//            return
//        }
//
//        // Find all graph states leveraging this component
//        let componentGraphStates = parentGraph.nodes.values
//            .compactMap { node -> GraphState? in
//                guard let component = node.nodeType.componentNode,
//                component.componentId == self.id else {
//                    return nil
//                }
//                return component.graph
//            }
//
//        componentGraphStates.forEach { graphState in
//            graphState.importedFilesDirectoryReceived(mediaFiles: mediaFiles,
//                                                      components: components)
//        }
//    }
}

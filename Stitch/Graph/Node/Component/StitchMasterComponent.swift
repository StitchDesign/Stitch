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
    @MainActor var componentData: StitchComponentData {
        .init(draft: self.draftedDocumentEncoder.lastEncodedDocument,
              published: self.publishedDocumentEncoder.lastEncodedDocument)
    }
    
    let id: UUID
    let saveLocation: GraphSaveLocation
    
    // Encoded copy of drafted component
    let draftedDocumentEncoder: ComponentEncoder
    let publishedDocumentEncoder: ComponentEncoder
    
    weak var parentGraph: GraphState?
    
    init(componentData: StitchComponentData,
         parentGraph: GraphState?) {
        self.id = componentData.draft.id
        self.saveLocation = componentData.draft.saveLocation
        self.draftedDocumentEncoder = .init(component: componentData.draft)
        self.publishedDocumentEncoder = .init(component: componentData.published)
        self.parentGraph = parentGraph
        
        if let parentGraph = parentGraph {
            self.initializeDelegate(parentGraph: parentGraph)
        }
    }
}

extension StitchMasterComponent {
    @MainActor var publishedComponent: StitchComponent? {
        self.componentData.published
    }
       
    @MainActor var draftedComponent: StitchComponent {
        self.componentData.draft
    }
    
//    func update(from schema: StitchComponentData) {
//        self.componentData = schema
//    }
    
    @MainActor func createSchema(from graph: GraphState) -> StitchComponent {
        let graph = graph.createSchema()
        var component = self.componentData.draft
        component.graph = graph
        return component
    }
    
    static func createObject(from entity: StitchComponent) -> Self {
        fatalError()
//        .init(componentData: entity,
//              parentGraph: nil)
    }
    
    func onPrototypeRestart() { }
    
    func initializeDelegate(parentGraph: GraphState) {
        self.parentGraph = parentGraph
        
        Task {
            await MainActor.run { [weak self] in
                guard let component = self else { return }
                component.draftedDocumentEncoder.delegate = component
                component.publishedDocumentEncoder.delegate = component
            }
        }
    }
}

typealias MasterComponentsDict = [UUID : StitchMasterComponent]

extension MasterComponentsDict {
    mutating func sync(with data: [StitchComponentData],
                       parentGraph: GraphState) {
        self.sync(with: data,
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
        guard !schema.isPublished,
              let graphs = self.parentGraph?.findComponentGraphStates(componentId: self.componentData.id) else {
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

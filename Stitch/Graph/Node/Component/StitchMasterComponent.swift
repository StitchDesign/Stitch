//
//  StitchMasterComponent.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/4/24.
//

import SwiftUI
import StitchSchemaKit

/// Tracks drafted and persisted versions of components, used to populate copies in graph.
@Observable
final class StitchMasterComponent: Sendable {
    let id: UUID
    @MainActor var lastEncodedDocument: StitchComponent
    
    // Encoded copy of drafted component
    let encoder: ComponentEncoder
    
    @MainActor weak var parentGraph: GraphState?
    
    @MainActor
    init(componentData: StitchComponent,
         parentGraph: GraphState?) {
        self.id = componentData.graph.id
        self.lastEncodedDocument = componentData
        self.encoder = .init(component: componentData)
        self.parentGraph = parentGraph
        
        if let parentGraph = parentGraph {
            self.assignReferences(parentGraph: parentGraph)
        }
    }
}

extension StitchMasterComponent {
    @MainActor
    var publishedDocumentEncoder: ComponentEncoder? {
        guard let storeDelegate = self.storeDelegate else { return nil }
        
        for system in storeDelegate.systems.values {
            if let componentEncoder = system.components.get(self.id)?.encoder {
                return componentEncoder
            }
        }
        
        return nil
    }
    
    @MainActor func createSchema(from graph: GraphState) -> StitchComponent {
        let graph = graph.createSchema()
        var component = self.lastEncodedDocument
        component.graph = graph
        return component
    }
    
    func onPrototypeRestart(document: StitchDocumentViewModel) { }
    
    // fka `initializeDelegate`
    @MainActor func assignReferences(parentGraph: GraphState) {
        self.parentGraph = parentGraph
        self.encoder.delegate = self
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
        // Updates thumbnail
        if let document = self.parentGraph?.documentDelegate {
            document.encodeProjectInBackground(willUpdateUndoHistory: false)
        }
        
        // Find all graphs using this component
        guard let graphs = self.parentGraph?.findComponentGraphStates(componentId: self.lastEncodedDocument.id) else {
            fatalErrorIfDebug()
            return
        }
        
        graphs.forEach { graph in
            graph.update(from: schema.graph,
                         rootUrl: schema.rootUrl)
        }
    }
    
    func update(from schema: StitchComponent, rootUrl: URL?) {
        self.lastEncodedDocument = schema
        
        guard let document = self.parentGraph?.documentDelegate else {
            return
        }
        
        let componentId = self.id
        
        // Find all graph states using this component
        for component in document.allComponents {
            guard component.componentId == componentId else {
                continue
            }
            
            component.graph.update(from: schema.graph,
                                   rootUrl: rootUrl)
        }
    }
    
    @MainActor
    var storeDelegate: StitchStore? {
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

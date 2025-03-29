//
//  StitchSystemViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/9/24.
//

import SwiftUI

@Observable
final class StitchSystemViewModel: Sendable, Identifiable {
    let id: StitchSystemType
    @MainActor var lastEncodedDocument: StitchSystem
    @MainActor var components: [UUID: StitchMasterComponent] = [:]
    let encoder: StitchSystemEncoder
    
    @MainActor weak var storeDelegate: StoreDelegate?

    @MainActor init(data: StitchSystem,
                    storeDelegate: StoreDelegate?) {
        self.id = data.id
        self.lastEncodedDocument = data
        self.encoder = .init(system: data,
                             delegate: nil)
        
        self.encoder.delegate = self
        self.storeDelegate = storeDelegate

        self.refreshComponents()
    }
    
    @MainActor
    func refreshComponents() {
        if let decodedFiles = DocumentEncoder
            .getDecodedFiles(rootUrl: self.encoder.rootUrl) {
            let newComponents = self.components.sync(with: decodedFiles.components,
                                                           updateCallback: { component, data in
                var data = data
                data.saveLocation = .systemComponent(self.id,
                                                     data.id)
                component.update(from: data,
                                 rootUrl: data.saveLocation.getRootDirectoryUrl())
            }) { data in
                var data = data
                data.saveLocation = .systemComponent(self.id,
                                                     data.id)
                
                return StitchMasterComponent(componentData: data,
                                             parentGraph: nil)
            }
            
            self.components = newComponents
        }
    }
}

extension StitchSystemViewModel: DocumentEncodableDelegate {
    func update(from schema: StitchSystem,
                rootUrl: URL) {
        // TODO: come back here
        fatalError()
    }
    
    @MainActor func createSchema(from graph: GraphState?) -> StitchSystem {
        self.lastEncodedDocument
    }
    
    @MainActor func willEncodeProject(schema: StitchSystem) { }

    func updateAsync(from schema: StitchSystem) async {
        // TODO: come back here
        fatalError()
    }
}

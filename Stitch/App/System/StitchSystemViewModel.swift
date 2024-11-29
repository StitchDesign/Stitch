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

        Task { [weak self] in
            await self?.refreshComponents()
        }
    }
    
    func refreshComponents() async {
        if let decodedFiles = await self.encoder.getDecodedFiles() {
            let newComponents = await self.components.sync(with: decodedFiles.components,
                                                         updateCallback: { component, data in
                var data = data
                data.saveLocation = .systemComponent(self.id,
                                                     data.id)
                await component.updateAsync(from: data)
            }) { data in
                var data = data
                data.saveLocation = .systemComponent(self.id,
                                                     data.id)
                
                return await StitchMasterComponent(componentData: data,
                                                   parentGraph: nil)
            }
            
            await MainActor.run { [weak self] in
                self?.components = newComponents
            }
        }
    }
}

extension StitchSystemViewModel: DocumentEncodableDelegate {
    @MainActor func createSchema(from graph: GraphState?) -> StitchSystem {
        self.lastEncodedDocument
    }
    
    @MainActor func willEncodeProject(schema: StitchSystem) { }

    func updateAsync(from schema: StitchSystem) async {
        // TODO: come back here
        fatalError()
    }
}

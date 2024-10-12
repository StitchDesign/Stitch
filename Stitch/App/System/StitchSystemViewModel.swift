//
//  StitchSystemViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/9/24.
//

import SwiftUI

@Observable
final class StitchSystemViewModel {
    var lastEncodedDocument: StitchSystem
    var components: [UUID: StitchMasterComponent] = [:]
    let encoder: StitchSystemEncoder
    
    weak var storeDelegate: StoreDelegate?

    @MainActor init(data: StitchSystem,
                    storeDelegate: StoreDelegate?) {
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
            self.components = await self.components.sync(with: decodedFiles.components,
                                                         updateCallback: { component, data in
                var data = data
                data.saveLocation = .systemComponent(self.id,
                                                     data.id)
                await component.update(from: data)
            }) { data in
                var data = data
                data.saveLocation = .systemComponent(self.id,
                                                     data.id)
                
                return await StitchMasterComponent(componentData: data,
                                                   parentGraph: nil)
            }
        }
    }
}

extension StitchSystemViewModel: Identifiable {
    var id: StitchSystemType { lastEncodedDocument.id }
}

extension StitchSystemViewModel: DocumentEncodableDelegate {
    @MainActor func createSchema(from graph: GraphState?) -> StitchSystem {
        self.lastEncodedDocument
    }
    
    @MainActor func willEncodeProject(schema: StitchSystem) { }

    func update(from schema: StitchSystem) async {
        // TODO: come back here
        fatalError()
    }
}
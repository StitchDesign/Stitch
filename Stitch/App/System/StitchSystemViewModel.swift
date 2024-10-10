//
//  StitchSystemViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/9/24.
//

import SwiftUI

final class StitchSystemViewModel {
    var data: StitchSystem
    var componentEncoders: [UUID: ComponentEncoder] = [:]
    let encoder: StitchSystemEncoder
    
    weak var storeDelegate: StoreDelegate?

    @MainActor init(data: StitchSystem,
                    storeDelegate: StoreDelegate?) {
        self.data = data
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
            self.componentEncoders = await self.componentEncoders.sync(with: decodedFiles.components,
                                                                       updateCallback: { encoder, data in
            }) { data in
                ComponentEncoder(component: data)
            }
        }
    }
}

extension StitchSystemViewModel: Identifiable {
    var id: StitchSystemType { data.id }
}

extension StitchSystemViewModel: DocumentEncodableDelegate {
    @MainActor func createSchema(from graph: GraphState?) -> StitchSystem {
        self.data
    }
    
    @MainActor func willEncodeProject(schema: StitchSystem) { }

    func update(from schema: StitchSystem) async {
        // TODO: come back here
        fatalError()
    }
}

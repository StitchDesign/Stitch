//
//  DirectoryObserverActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation

struct DirectoryUpdated: StitchStoreEvent {
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        let isHomeScreenOpen = store.currentDocument != nil
        
        Task.detached(priority: isHomeScreenOpen ? .high : .low) { [weak store] in
            await store?.directoryUpdated()
        }
        
        return .noChange
    }
}

typealias SystemsDict = [StitchSystemType : StitchSystemViewModel]

extension StitchSystemType: Sendable { }

extension StitchStore: DirectoryObserverDelegate {
    func directoryUpdated() async {
        guard let response = await self.documentLoader.directoryUpdated() else {
            log("StitchStore.directoryUpdated error: no response for URLs found.")
            return
        }
        
        let newSystems = await self.systems.sync(with: response.systems,
                                               updateCallback: { viewModel, data in
            await MainActor.run { [weak viewModel] in
                viewModel?.lastEncodedDocument = data
            }
            await viewModel.refreshComponents()
        }) { data in
            await StitchSystemViewModel(data: data,
                                        storeDelegate: self)
        }
        
        await MainActor.run { [weak self] in
            guard let store = self else {
                return
            }

            store.systems = newSystems
            
            store.allProjectUrls = response.projects
        }
    }
}

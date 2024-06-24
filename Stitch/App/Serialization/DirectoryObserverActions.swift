//
//  DirectoryObserverActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation

struct DirectoryUpdated: StitchStoreEvent {
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.directoryUpdated()
        return .noChange
    }
}

extension StitchStore: DirectoryObserverDelegate {
    func directoryUpdated() {
        Task.detached { [weak self] in
            guard let store = self else {
                return
            }

            guard let newProjectUrls = await store.documentLoader.directoryUpdated() else {
                log("StitchStore.directoryUpdated error: no response for URLs found.")
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let store = self else {
                    return
                }

                store.allProjectUrls = newProjectUrls
            }
        }
    }
}

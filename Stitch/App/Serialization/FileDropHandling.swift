//
//  FileDropHandling.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import StitchSchemaKit

@MainActor
func handleOnDrop(providers: [NSItemProvider],
                  location: CGPoint,
                  store: StitchStore) -> Bool {

    let incrementSize = CGFloat(NODE_POSITION_STAGGER_SIZE)
    var droppedLocation = location

    // handles MULTIPLE ACTIONS ETC.
    for provider in providers {
        let finalDroppedLocation = droppedLocation

        provider.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) { url, _ in
            guard let url = url else {
                DispatchQueue.main.async {
                    dispatch(ReceivedStitchFileError(error: .droppedMediaFileFailed))
                }
                return
            }

            // MARK: due to async logic of dispatched effects, the provided temporary URL has a tendancy to expire, so a new URL is created.
            let tempURL = StitchFileManager.tempDir.appendingPathComponent(url.filename).appendingPathExtension(url.pathExtension)

            let _ = url.startAccessingSecurityScopedResource()

            // Default FileManager ok here given we just need a temp URL
            try? FileManager.default.copyItem(at: url, to: tempURL)
            url.stopAccessingSecurityScopedResource()

            // Opens stitch documents
            guard tempURL.pathExtension != STITCH_EXTENSION_RAW else {
                Task(priority: .high) { [weak store] in
                    do {
                        switch await store?.documentLoader.loadDocument(from: tempURL,
                                                                        isImport: true) {
                        case .loaded(let data, _):
                            await store?.createNewProject(from: data)
                       default:
                            DispatchQueue.main.async {
                                dispatch(DisplayError(error: .unsupportedProject))
                            }
                            return
                        }
                    }
                }
                return
            }

            #if targetEnvironment(macCatalyst)
            // Fixes issue on Catalyst where dropped location is mysteriously too high (visually) on screen
            droppedLocation.y += 50
            #endif

            let _ = tempURL.startAccessingSecurityScopedResource()

            DispatchQueue.main.async {
                dispatch(ImportFileToNewNode(url: tempURL, 
                                             droppedLocation: finalDroppedLocation))
            }

            tempURL.stopAccessingSecurityScopedResource()
        }
        
        // Increment dropped location so items don't stack directly
        // ontop of each other
        droppedLocation.x += incrementSize
        droppedLocation.y += incrementSize
    }

    return true
}

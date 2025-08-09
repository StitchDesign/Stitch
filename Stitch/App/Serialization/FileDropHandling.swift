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

// On drop of a file (media, Stitch project etc.) onto the Stitch app window
@MainActor
func handleOnDrop(providers: [NSItemProvider],
                  // TODO: converting provided `location` to canvas' coordinate-space
                  location: CGPoint,
                  store: StitchStore) -> Bool {
    
    let temporaryDirectoryURL = TemporaryDirectoryURL()
        
    // handles files being dropped
    for provider in providers {
        provider.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) { url, _ in
            guard let url = url,
                  let tempURL = TemporaryURL.pathAndCopy(url: url, temporaryDirectoryURL) else {
                DispatchQueue.main.async {
                    // TODO: cannot assume we dropped a media file; could have dropped e.g. a Stitch project
                    dispatch(ReceivedStitchFileError(error: .droppedMediaFileFailed))
                }
                return
            }
            Task { @MainActor in
                handleDroppedFile(tempURL: tempURL, store: store)
            }
        }
    }
    
    return true
}

@MainActor
func handleDroppedFile(tempURL: TemporaryURL,
                       store: StitchStore) {
 
    // importing a Stitch project
    if tempURL.value.isStitchDocumentExtension {
        Task(priority: .high) { [weak store] in
            do {
                switch await store?.documentLoader.loadDocument(from: tempURL.value,
                                                                isImport: true) {
                    
                case .loaded(let data, _):
                    await store?.createNewProject(from: data,
                                                  isProjectImport: true,
                                                  enterProjectImmediately: true)
                    
                default:
                    DispatchQueue.main.async {
                        dispatch(DisplayError(error: .unsupportedProject))
                    }
                    return
                }
            }
        }
    }
    
    // importing a media file
    else {
        let _ = tempURL.value.startAccessingSecurityScopedResource()
        
        // Check if insert node menu is open - if so, handle as AI image input
        if let document = store.currentDocument,
           document.insertNodeMenuState.show,
           isImageFile(pathExtension: tempURL.value.pathExtension) {
            
            // Load image for AI Vision API
            DispatchQueue.main.async {
                if let image = UIImage(contentsOfFile: tempURL.value.path) {
                    dispatch(HandleInsertNodeMenuImageDrop(image: image))
                } else {
                    log("Failed to load dropped image file")
                }
            }
        }
        // Otherwise, create media node as usual
        else {
            DispatchQueue.main.async {
                dispatch(ImportFileToNewNode(url: tempURL.value))
            }
        }
        
        tempURL.value.stopAccessingSecurityScopedResource()
    }
}


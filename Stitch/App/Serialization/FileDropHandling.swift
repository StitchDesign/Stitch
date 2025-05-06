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
                  let tempURL = TemporaryURL(url: url, temporaryDirectoryURL) else {
                DispatchQueue.main.async {
                    // TODO: cannot assume we dropped a media file; could have dropped e.g. a Stitch project
                    dispatch(ReceivedStitchFileError(error: .droppedMediaFileFailed))
                }
                return
            }
            
            handleDroppedFile(tempURL: tempURL, store: store)
        }
    }
    
    return true
}

func handleDroppedFile(tempURL: TemporaryURL,
                       store: StitchStore) {
 
    // importing a Stitch project
    if tempURL.value.isStitchDocumentExtension {
        importStitchProjectSideEffect(tempURL: tempURL, store: store)
    }
    
    // importing a media file
    else {
        importMediaFileToStitch(tempURL: tempURL)
    }
}


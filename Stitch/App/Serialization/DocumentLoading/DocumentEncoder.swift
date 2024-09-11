//
//  DocumentEncoder.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 3/1/24.
//

import SwiftUI
import StitchSchemaKit

actor DocumentEncoder {
    // Keeps track of last saved StitchDocument to disk
    @MainActor var lastEncodedData: StitchDocumentData
    
    init(data: StitchDocumentData) {
        self.lastEncodedData = data
    }
    
    func encodeProject(_ data: StitchDocumentData,
                       temporaryURL: DocumentsURL? = nil,
                       documentLoader: DocumentLoader) async -> StitchFileVoidResult {
        let rootDocUrl = temporaryURL?.url ?? data.document.rootUrl
        
        do {
            // Encode document
            try DocumentLoader.encodeDocument(data.document,
                                              to: rootDocUrl)
            
            // Encode document-level published components
            for component in data.publishedDocumentComponents {
                try DocumentLoader.encodeDocument(component,
                                                        to: rootDocUrl)
            }
            
            log("encodeProject success")

            // Save data for last encoded document
            await MainActor.run { [weak self] in
                self?.lastEncodedData = data
            }
            
            // Gets home screen to update with latest doc version
            await dispatch(DirectoryUpdated())

            return .success
        } catch {
            log("encodeProject failed: \(error)")
            fatalErrorIfDebug()
            return .failure(.versionableContainerEncodingFailed)
        }
    }
}

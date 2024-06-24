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
    @MainActor var lastEncodedDocument: StitchDocument
    
    init(document: StitchDocument) {
        self.lastEncodedDocument = document
    }
    
    func encodeProject(_ document: StitchDocument,
                       temporaryURL: DocumentsURL? = nil,
                       documentLoader: DocumentLoader) async -> StitchFileVoidResult {
        do {
            try await documentLoader.encodeVersionedContents(document: document,
                                                             directoryUrl: temporaryURL?.url)
            log("encodeProject success")

            // Save data for last encoded document
            await MainActor.run { [weak self] in
                self?.lastEncodedDocument = document
            }

            return .success
        } catch {
            log("encodeProject failed: \(error)")
            fatalErrorIfDebug()
            return .failure(.versionableContainerEncodingFailed)
        }
    }
}

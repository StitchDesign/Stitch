//
//  DocumentEncoder.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 3/1/24.
//

import SwiftUI
import StitchSchemaKit

protocol DocumentEncodable: Actor {
    associatedtype CodableDocument: StitchDocumentEncodable & Sendable
    
    var lastEncodedDocument: CodableDocument { get set }
    
    var rootUrl: URL { get }
    
    var recentlyDeletedUrl: URL { get }
}

extension DocumentEncodable {
    func encodeProject(_ document: Self.CodableDocument,
                       temporaryURL: DocumentsURL? = nil) async -> StitchFileVoidResult {
        let rootDocUrl = temporaryURL?.url ?? self.rootUrl
        
        do {
            // Encode document
            try DocumentLoader.encodeDocument(document,
                                              to: rootDocUrl)
            
//            // Encode document-level published components
//            for component in data.publishedDocumentComponents {
//                try DocumentLoader.encodeDocument(component,
//                                                  to: rootDocUrl)
//            }
            
            log("encodeProject success")

            // Save data for last encoded document
            self.lastEncodedDocument = document
            
            // Gets home screen to update with latest doc version
            await dispatch(DirectoryUpdated())

            return .success
        } catch {
            log("encodeProject failed: \(error)")
            fatalErrorIfDebug()
            return .failure(.versionableContainerEncodingFailed)
        }
    }
    
    var id: UUID {
        self.lastEncodedDocument.id
    }
}

//extension StitchDocument: StitchDocumentEncodable {
//    func getEncodingUrl(documentRootUrl: URL) -> URL {
//        <#code#>
//    }
//}

actor DocumentEncoder: DocumentEncodable {
    // Keeps track of last saved StitchDocument to disk
    @MainActor var lastEncodedDocument: StitchDocument
    
    init(document: StitchDocument) {
        self.lastEncodedDocument = document
    }
}

extension DocumentEncoder {
    var rootUrl: URL {
        StitchFileManager.documentsURL
            .url
            .appendingStitchProjectDataPath(self.id)
    }
    
    var recentlyDeletedUrl: URL {
        StitchDocument.recentlyDeletedURL.appendingStitchProjectDataPath(self.id)
    }
}

actor ComponentEncoder: DocumentEncodable {
    // Keeps track of last saved StitchDocument to disk
    @MainActor var lastEncodedDocument: StitchComponent
    
    var rootUrl: URL
    
    init(component: StitchComponent,
         saveLocation: ComponentSaveLocation) {
        self.lastEncodedDocument = component
        self.rootUrl = saveLocation.rootUrl
    }
}

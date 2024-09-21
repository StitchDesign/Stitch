//
//  DocumentEncoder.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 3/1/24.
//

import SwiftUI
import StitchSchemaKit

protocol DocumentEncodable: Actor {
    associatedtype DocumentDelegate: DocumentEncodableDelegate
    associatedtype CodableDocument: StitchDocumentEncodable & Sendable
//    typealias CodableDocument = DocumentDelegate.CodableDocument
    
    var lastEncodedDocument: CodableDocument { get set }
    
    var rootUrl: URL { get }
    
    @MainActor var delegate: DocumentDelegate? { get }
}

protocol DocumentEncodableDelegate: AnyObject {
    @MainActor
    func importedFilesDirectoryReceived(mediaFiles: [URL],
                                        publishedComponents: [StitchComponent])
}

extension DocumentEncodable {
    var id: UUID {
        self.lastEncodedDocument.id
    }
    
    var recentlyDeletedUrl: URL {
        StitchDocument.recentlyDeletedURL.appendingStitchProjectDataPath(self.id)
    }
    
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
}

//extension StitchDocument: StitchDocumentEncodable {
//    func getEncodingUrl(documentRootUrl: URL) -> URL {
//        <#code#>
//    }
//}

final actor DocumentEncoder: DocumentEncodable {
    // Keeps track of last saved StitchDocument to disk
    var lastEncodedDocument: StitchDocument
    @MainActor weak var delegate: StitchDocumentViewModel?
    
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
}

final actor ComponentEncoder: DocumentEncodable {
    // Keeps track of last saved StitchDocument to disk
    var lastEncodedDocument: StitchComponent
    var rootUrl: URL
    @MainActor weak var delegate: StitchMasterComponent?
    
    init(component: StitchComponent) {
        self.lastEncodedDocument = component
        self.rootUrl = component.saveLocation.rootUrl
    }
}

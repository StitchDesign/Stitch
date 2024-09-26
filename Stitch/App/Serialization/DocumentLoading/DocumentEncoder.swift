//
//  DocumentEncoder.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 3/1/24.
//

import SwiftUI
import StitchSchemaKit

protocol DocumentEncodable: Actor where CodableDocument == DocumentDelegate.CodableDocument {
    associatedtype DocumentDelegate: DocumentEncodableDelegate
    associatedtype CodableDocument: StitchDocumentEncodable & Sendable
    
    var lastEncodedDocument: CodableDocument { get set }
    
    var rootUrl: URL { get }
    
    @MainActor var delegate: DocumentDelegate? { get }
}

protocol DocumentEncodableDelegate: AnyObject {
    associatedtype CodableDocument: Codable
    
    @MainActor func createSchema() -> CodableDocument
    
    @MainActor
    func willEncodeProject(schema: CodableDocument)
    
//    @MainActor
//    func importedFilesDirectoryReceived(mediaFiles: [URL],
//                                        components: [StitchComponentData])
}

extension DocumentEncodable {
    @MainActor func encodeProjectInBackground(temporaryUrl: DocumentsURL? = nil) {
        guard let delegate = self.delegate else { return }
        let newSchema = delegate.createSchema()
        delegate.willEncodeProject(schema: newSchema)
        
        Task(priority: .background) {
            await self.encodeProject(newSchema,
                                     temporaryURL: temporaryUrl)
        }
    }
    
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
    var lastEncodedDocument: StitchComponentData
    @MainActor weak var delegate: StitchMasterComponent?
    
    init(component: StitchComponentData) {
        self.lastEncodedDocument = component
    }
}

extension ComponentEncoder {
    var rootUrl: URL {
        lastEncodedDocument.rootUrl
    }
}

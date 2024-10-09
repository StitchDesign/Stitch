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
    
    @MainActor var lastEncodedDocument: CodableDocument { get set }
    
    var documentId: CodableDocument.ID { get set }
    
    var saveLocation: EncoderDirectoryLocation { get }
    
    @MainActor var delegate: DocumentDelegate? { get }
}

protocol DocumentEncodableDelegate: AnyObject {
    associatedtype CodableDocument: Codable
    
    @MainActor func createSchema(from graph: GraphState?) -> CodableDocument
    
    @MainActor func willEncodeProject(schema: CodableDocument)

    func updateOnUndo(schema: CodableDocument)
    
    var storeDelegate: StoreDelegate? { get }
}

extension DocumentEncodable {
    @MainActor func encodeProjectInBackground(from graph: GraphState?,
                                              temporaryUrl: URL? = nil,
                                              wasUndo: Bool = false) {
        self.encodeProjectInBackground(from: graph,
                                       temporaryUrl: temporaryUrl,
                                       wasUndo: wasUndo) { delegate, oldSchema, newSchema in
            
            if let graph = graph {
                graph.storeDelegate?.saveUndoHistory(from: delegate,
                                                     oldSchema: oldSchema,
                                                     newSchema: newSchema,
                                                     undoEffectsData: nil)
            }
        }
    }
    
    @MainActor func encodeProjectInBackground(from graph: GraphState?,
                                              undoEvents: [Action],
                                              temporaryUrl: URL? = nil,
                                              wasUndo: Bool = false) {
        self.encodeProjectInBackground(from: graph,
                                       temporaryUrl: temporaryUrl,
                                       wasUndo: wasUndo) { delegate, oldSchema, newSchema in
            if let graph = graph {
                graph.storeDelegate?.saveUndoHistory(from: delegate,
                                                     oldSchema: oldSchema,
                                                     newSchema: newSchema,
                                                     undoEvents: undoEvents,
                                                     redoEvents: [])
            }
        }
    }
    
    @MainActor func encodeProjectInBackground(from graph: GraphState?,
                                              temporaryUrl: URL? = nil,
                                              wasUndo: Bool = false,
                                              saveUndoHistory: @escaping (DocumentDelegate, CodableDocument, CodableDocument) -> ()) {
        guard let delegate = self.delegate else {
            fatalErrorIfDebug()
            return
        }
        
        let newSchema = delegate.createSchema(from: graph)
        delegate.willEncodeProject(schema: newSchema)
        
        // Make schema changes like document
        let oldSchema = self.lastEncodedDocument
        
        // Update undo only if the caller here wasn't undo itself--this breaks redo
        if !wasUndo {
            saveUndoHistory(delegate, oldSchema, newSchema)
        }
        
        Task(priority: .background) {
            await self.encodeProject(newSchema,
                                     temporaryURL: temporaryUrl)
        }
    }
    
    var rootUrl: URL {
        self.saveLocation.getRootDirectoryUrl()
    }
    
    var recentlyDeletedUrl: URL {
        StitchDocument.recentlyDeletedURL.appendingStitchProjectDataPath("\(self.documentId)")
    }
    
    func encodeProject(_ document: Self.CodableDocument,
                       temporaryURL: URL? = nil) async -> StitchFileVoidResult {
        let rootDocUrl = temporaryURL ?? self.rootUrl.appendingVersionedSchemaPath()
        
        do {
            // Encode document
            try Self.CodableDocument.encodeDocument(document,
                                                    to: rootDocUrl)
            
            log("encodeProject success")

            // Save data for last encoded document
            await MainActor.run { [weak self] in
                self?.lastEncodedDocument = document
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

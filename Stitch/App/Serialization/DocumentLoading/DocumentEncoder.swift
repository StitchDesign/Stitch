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
    
    var id: UUID { get set }
    
    var rootUrl: URL { get }
    
    @MainActor var delegate: DocumentDelegate? { get }
}

protocol DocumentEncodableDelegate: AnyObject {
    associatedtype CodableDocument: Codable
    
    @MainActor func createSchema(from graph: GraphState) -> CodableDocument
    
    @MainActor func willEncodeProject(schema: CodableDocument)

    func updateOnUndo(schema: CodableDocument)
    
    var storeDelegate: StoreDelegate? { get }
}

extension DocumentEncodable {
    @MainActor func encodeProjectInBackground(from graph: GraphState,
                                              temporaryUrl: DocumentsURL? = nil,
                                              wasUndo: Bool = false) {
        self.encodeProjectInBackground(from: graph,
                                       temporaryUrl: temporaryUrl,
                                       wasUndo: wasUndo) { delegate, oldSchema, newSchema in
            graph.storeDelegate?.saveUndoHistory(from: delegate,
                                                 oldSchema: oldSchema,
                                                 newSchema: newSchema,
                                                 undoEffectsData: nil)
        }
    }
    
    @MainActor func encodeProjectInBackground(from graph: GraphState,
                                              undoEvents: [Action],
                                              temporaryUrl: DocumentsURL? = nil,
                                              wasUndo: Bool = false) {
        self.encodeProjectInBackground(from: graph,
                                       temporaryUrl: temporaryUrl,
                                       wasUndo: wasUndo) { delegate, oldSchema, newSchema in
            graph.storeDelegate?.saveUndoHistory(from: delegate,
                                                 oldSchema: oldSchema,
                                                 newSchema: newSchema,
                                                 undoEvents: undoEvents,
                                                 redoEvents: [])
        }
    }
    
    @MainActor func encodeProjectInBackground(from graph: GraphState,
                                              temporaryUrl: DocumentsURL? = nil,
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

final actor DocumentEncoder: DocumentEncodable {
    var id: UUID
    
    // Keeps track of last saved StitchDocument to disk
    @MainActor var lastEncodedDocument: StitchDocument
    @MainActor weak var delegate: StitchDocumentViewModel?
    
    init(document: StitchDocument) {
        self.id = document.graph.id
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
    var id: UUID
    let rootUrl: URL
    
    // Keeps track of last saved StitchDocument to disk
    @MainActor var lastEncodedDocument: StitchComponent
    @MainActor weak var delegate: StitchMasterComponent?
    
    init(component: StitchComponent) {
        self.id = component.id
        self.lastEncodedDocument = component
        self.rootUrl = component.rootUrl
    }
}


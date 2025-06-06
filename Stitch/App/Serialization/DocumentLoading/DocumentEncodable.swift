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
    
    var documentId: CodableDocument.ID { get }
    
    nonisolated var saveLocation: EncoderDirectoryLocation? { get }
    
    @MainActor var delegate: DocumentDelegate? { get }
}

protocol DocumentEncodableDelegate: Observable, AnyObject, Sendable {
    associatedtype CodableDocument: Codable & Sendable
    
    @MainActor var lastEncodedDocument: CodableDocument { get set }
    
    @MainActor func createSchema(from graph: GraphState) -> CodableDocument
        
    @MainActor func update(from schema: CodableDocument, rootUrl: URL?)
    
    @MainActor func willEncodeProject(schema: CodableDocument)
    
    @MainActor func didEncodeProject(schema: CodableDocument)    
}

extension DocumentEncodableDelegate {
    // Default function to make it optional to define.
    @MainActor func didEncodeProject(schema: CodableDocument) { }
}

extension DocumentEncodable {
    @MainActor var lastEncodedDocument: CodableDocument {
        get {
            self.delegate?.lastEncodedDocument ?? Self.CodableDocument()
        } set(newValue) {
            self.delegate?.lastEncodedDocument = newValue
        }
    }
    
    // TODO: can we collapse these into a single function call?
    @MainActor func encodeProjectInBackground(from graph: GraphState,
                                              temporaryUrl: URL? = nil,
                                              willUpdateUndoHistory: Bool = true,
                                              store: StitchStore) {
        self.encodeProjectInBackground(from: graph,
                                       temporaryUrl: temporaryUrl,
                                       willUpdateUndoHistory: willUpdateUndoHistory) { delegate, oldSchema, newSchema in
            if willUpdateUndoHistory,
               let rootUrl = self.rootUrl {
                store.saveUndoHistory(from: delegate,
                                      oldSchema: oldSchema,
                                      newSchema: newSchema,
                                      rootUrl: rootUrl,
                                      undoEffectsData: nil)
            }
        }
    }
    
    @MainActor func encodeProjectInBackground(from graph: GraphState,
                                              undoEvents: [Action],
                                              temporaryUrl: URL? = nil,
                                              willUpdateUndoHistory: Bool = true,
                                              store: StitchStore) {
        self.encodeProjectInBackground(from: graph,
                                       temporaryUrl: temporaryUrl,
                                       willUpdateUndoHistory: willUpdateUndoHistory) { delegate, oldSchema, newSchema in
            if willUpdateUndoHistory,
               let rootUrl = self.rootUrl {
                store.saveUndoHistory(from: delegate,
                                      oldSchema: oldSchema,
                                      newSchema: newSchema,
                                      rootUrl: rootUrl,
                                      undoEvents: undoEvents,
                                      redoEvents: [])
            }
        }
    }
    
    @MainActor func encodeProjectInBackground(from graph: GraphState,
                                              temporaryUrl: URL? = nil,
                                              willUpdateUndoHistory: Bool = true,
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
        if willUpdateUndoHistory {
            saveUndoHistory(delegate, oldSchema, newSchema)
        }
        
        // medium priority fixes issue where encoding here enters queue with same priority as potentially many projects, thus not updating disk fast enough if user exits project
        Task(priority: .medium) { [weak self] in
            guard let encoder = self else {
                return
            }
            
            let _ = await encoder.encodeProject(newSchema,
                                                willUpdateUndoHistory: willUpdateUndoHistory,
                                                temporaryURL: temporaryUrl)
        }
    }
    
    nonisolated var rootUrl: URL? {
        self.saveLocation?.getRootDirectoryUrl()
    }
    
    var recentlyDeletedUrl: URL {
        StitchFileManager.recentlyDeletedURL.appendingStitchProjectDataPath("\(self.documentId)")
    }
    
    func encodeProject(_ document: Self.CodableDocument,
                       willUpdateUndoHistory: Bool = true,
                       temporaryURL: URL? = nil) async -> StitchFileVoidResult {
        guard let rootDocUrl = temporaryURL ?? self.rootUrl?.appendingVersionedSchemaPath() else {
            return .failure(.persistenceDisabled)
        }
        
        do {
            // Encode document
            try Self.CodableDocument.encodeDocument(document,
                                                    to: rootDocUrl)
            
            log("encodeProject success")

            // Save data for last encoded document whenever there was undo history saved
            if willUpdateUndoHistory {
                await MainActor.run { [weak self] in
                    self?.lastEncodedDocument = document
                    self?.delegate?.didEncodeProject(schema: document)
                }
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

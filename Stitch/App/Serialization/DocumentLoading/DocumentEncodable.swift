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
    
    var saveLocation: EncoderDirectoryLocation { get }
    
    @MainActor var delegate: DocumentDelegate? { get }
}

protocol DocumentEncodableDelegate: Observable, AnyObject, Sendable {
    associatedtype CodableDocument: Codable & Sendable
    
    @MainActor var lastEncodedDocument: CodableDocument { get set }
    
    @MainActor func createSchema(from graph: GraphState?) -> CodableDocument
    
    func updateAsync(from schema: CodableDocument) async
    
    @MainActor func willEncodeProject(schema: CodableDocument)
    
    @MainActor func didEncodeProject(schema: CodableDocument)
    
    @MainActor var storeDelegate: StoreDelegate? { get }
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
    
    @MainActor func encodeProjectInBackground(from graph: GraphState?,
                                              temporaryUrl: URL? = nil,
                                              willUpdateUndoHistory: Bool = true) {
        self.encodeProjectInBackground(from: graph,
                                       temporaryUrl: temporaryUrl,
                                       willUpdateUndoHistory: willUpdateUndoHistory) { delegate, oldSchema, newSchema in
            
            if willUpdateUndoHistory,
               let graph = graph {
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
                                              willUpdateUndoHistory: Bool = true) {
        self.encodeProjectInBackground(from: graph,
                                       temporaryUrl: temporaryUrl,
                                       willUpdateUndoHistory: willUpdateUndoHistory) { delegate, oldSchema, newSchema in
            if willUpdateUndoHistory,
                let graph = graph {
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
    
    var rootUrl: URL {
        self.saveLocation.getRootDirectoryUrl()
    }
    
    var recentlyDeletedUrl: URL {
        StitchFileManager.recentlyDeletedURL.appendingStitchProjectDataPath("\(self.documentId)")
    }
    
    func encodeProject(_ document: Self.CodableDocument,
                       willUpdateUndoHistory: Bool = true,
                       temporaryURL: URL? = nil) async -> StitchFileVoidResult {
        let rootDocUrl = temporaryURL ?? self.rootUrl.appendingVersionedSchemaPath()
        
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

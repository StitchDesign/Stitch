//
//  StoreDelegate.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation

protocol StoreDelegate: AnyObject {
    var documentLoader: DocumentLoader { get }
    
    var systems: [StitchSystemType: StitchSystemViewModel] { get }
    
    var clipboardEncoder: ClipboardEncoder { get }

    @MainActor
    func saveProjectDeletionUndoHistory(undoActions: [Action],
                                        redoActions: [Action])

    @MainActor
    func saveUndoHistory<EncoderDelegate>(from encoderDelegate: EncoderDelegate,
                                          oldSchema: EncoderDelegate.CodableDocument,
                                          newSchema: EncoderDelegate.CodableDocument,
                                          undoEvents: Actions?,
                                          redoEvents: Actions?) where EncoderDelegate: DocumentEncodableDelegate
    
    @MainActor
    func saveUndoHistory<EncoderDelegate>(from encoderDelegate: EncoderDelegate,
                                          oldSchema: EncoderDelegate.CodableDocument,
                                          newSchema: EncoderDelegate.CodableDocument,
                                          undoEffectsData: UndoEffectsData?) where EncoderDelegate: DocumentEncodableDelegate
    
    @MainActor
    func saveComponentToUserLibrary(_ component: StitchComponent) throws
}

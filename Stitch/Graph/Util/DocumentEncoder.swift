//
//  DocumentEncoder.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/7/24.
//

import SwiftUI
import StitchSchemaKit

final actor DocumentEncoder: DocumentEncodable {
    let documentId: UUID
    
    // Nil case allows for no encoding saving (used by graph viewer)
    let saveLocation: EncoderDirectoryLocation?
    
    @MainActor weak var delegate: StitchDocumentViewModel?
    
    @MainActor
    init(document: StitchDocument,
         disableSaves: Bool = false) {
        self.saveLocation = disableSaves ? nil : .document(.document(document.id))
        self.documentId = document.graph.id
        self.lastEncodedDocument = document
    }
}

final actor ComponentEncoder: DocumentEncodable {
    let id: UUID
    var documentId: UUID
    let saveLocation: EncoderDirectoryLocation?
    
    @MainActor weak var delegate: StitchMasterComponent?
    
    init(component: StitchComponent) {
        self.id = component.graphEntity.id
        self.documentId = component.id
        self.saveLocation = .document(component.saveLocation)
    }
}

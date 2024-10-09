//
//  DocumentEncoder.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/7/24.
//

import SwiftUI
import StitchSchemaKit

final actor DocumentEncoder: DocumentEncodable {
    var documentId: UUID
    var saveLocation: EncoderDirectoryLocation
    
    // Keeps track of last saved StitchDocument to disk
    @MainActor var lastEncodedDocument: StitchDocument
    @MainActor weak var delegate: StitchDocumentViewModel?
    
    init(document: StitchDocument) {
        self.saveLocation = .document(.document(document.id))
        self.documentId = document.graph.id
        self.lastEncodedDocument = document
    }
}


final actor ComponentEncoder: DocumentEncodable {
    var documentId: UUID
    let saveLocation: EncoderDirectoryLocation
    
    // Keeps track of last saved StitchDocument to disk
    @MainActor var lastEncodedDocument: StitchComponent
    @MainActor weak var delegate: StitchMasterComponent?
    
    init(component: StitchComponent) {
        self.documentId = component.id
        self.lastEncodedDocument = component
        self.saveLocation = .document(component.saveLocation)
    }
}

extension ComponentEncoder: Identifiable {
    @MainActor var id: UUID {
        self.lastEncodedDocument.id
    }
}


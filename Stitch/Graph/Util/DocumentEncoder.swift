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
    
    @MainActor weak var delegate: StitchMasterComponent?
    
    init(component: StitchComponent) {
        self.documentId = component.id
        self.saveLocation = .document(component.saveLocation)
    }
}

extension ComponentEncoder: Identifiable {
    @MainActor var id: UUID {
        self.lastEncodedDocument.id
    }
}


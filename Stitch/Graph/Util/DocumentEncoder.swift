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
    let saveLocation: EncoderDirectoryLocation
    
    @MainActor weak var delegate: StitchDocumentViewModel?
    
    @MainActor
    init(document: StitchDocument) {
        self.saveLocation = .document(.document(document.id))
        self.documentId = document.graph.id
        self.lastEncodedDocument = document
    }
}


final actor ComponentEncoder: DocumentEncodable {
    let id: UUID
    var documentId: UUID
    let saveLocation: EncoderDirectoryLocation
    
    @MainActor weak var delegate: StitchMasterComponent?
    
    init(component: StitchComponent) {
        self.id = component.graph.id
        self.documentId = component.id
        self.saveLocation = .document(component.saveLocation)
    }
}

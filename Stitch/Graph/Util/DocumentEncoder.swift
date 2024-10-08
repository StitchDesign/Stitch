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
    
    // Keeps track of last saved StitchDocument to disk
    @MainActor var lastEncodedDocument: StitchDocument
    @MainActor weak var delegate: StitchDocumentViewModel?
    
    init(document: StitchDocument) {
        self.documentId = document.graph.id
        self.lastEncodedDocument = document
    }
}

extension DocumentEncoder {
    var rootUrl: URL {
        StitchFileManager.documentsURL
            .appendingStitchProjectDataPath("\(self.documentId)")
    }
}

final actor ComponentEncoder: DocumentEncodable {
    var documentId: UUID
    let rootUrl: URL
    
    // Keeps track of last saved StitchDocument to disk
    @MainActor var lastEncodedDocument: StitchComponent
    @MainActor weak var delegate: StitchMasterComponent?
    
    init(component: StitchComponent) {
        self.documentId = component.id
        self.lastEncodedDocument = component
        self.rootUrl = component.rootUrl
    }
}

extension ComponentEncoder: Identifiable {
    @MainActor var id: UUID {
        self.lastEncodedDocument.id
    }
}


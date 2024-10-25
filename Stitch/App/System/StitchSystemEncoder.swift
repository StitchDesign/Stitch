//
//  StitchSystemEncoder.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/9/24.
//

import SwiftUI

final actor StitchSystemEncoder: DocumentEncodable {
    var documentId: StitchSystemType
    let saveLocation: EncoderDirectoryLocation
    
    @MainActor weak var delegate: StitchSystemViewModel?
    
    init(system: StitchSystem,
         delegate: StitchSystemViewModel?) {
        self.documentId = system.id
        self.saveLocation = .document(.system(system.id))
        self.delegate = delegate
    }
}

// TODO: move
final actor ClipboardEncoder: DocumentEncodable {
    var documentId: UUID = .init()
    let saveLocation: EncoderDirectoryLocation
    
    @MainActor var lastEncodedDocument: StitchClipboardContent
    @MainActor weak var delegate: ClipboardEncoderDelegate?
    
    init() {
        self.lastEncodedDocument = .init()
        self.saveLocation = .clipboard
    }
}

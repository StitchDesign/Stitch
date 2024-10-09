//
//  StitchSystemEncoder.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/9/24.
//

import SwiftUI

final actor StitchSystemEncoder: DocumentEncodable {
    var documentId: StitchSystemType
    let rootUrl: URL
    let saveLocation: GraphSaveLocation
    
    @MainActor var lastEncodedDocument: StitchSystem
    @MainActor weak var delegate: StitchSystemViewModel?
    
    init(system: StitchSystem,
         delegate: StitchSystemViewModel?) {
        self.documentId = system.id
        self.lastEncodedDocument = system
        self.rootUrl = system.rootUrl
        self.saveLocation = .system(system.id)
        self.delegate = delegate
    }
}

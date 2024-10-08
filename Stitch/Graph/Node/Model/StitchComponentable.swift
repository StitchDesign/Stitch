//
//  StitchComponentable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/3/24.
//

import SwiftUI
import StitchSchemaKit

protocol StitchComponentable: StitchDocumentEncodable {
    var graph: GraphEntity { get set }
}

extension StitchDocumentEncodable {
    @Sendable
    static func encodeDocument(_ document: Self) throws {
        try Self.encodeDocument(document,
                                to: document.rootUrl.appendingVersionedSchemaPath())
    }
    
    @Sendable
    static func encodeDocument(_ document: Self, to url: URL) throws {
        let encodedData = try getStitchEncoder().encode(document)
        try encodedData.write(to: url, options: .atomic)
    }
}

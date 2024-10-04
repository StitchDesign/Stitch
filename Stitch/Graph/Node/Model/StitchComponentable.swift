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

extension StitchComponentable {
    @Sendable
    static func exportComponent(_ component: Self,
                                rootUrl: URL? = nil) async {
        let rootUrl = rootUrl ?? component.rootUrl
        
        // Create directories if it doesn't exist
        let _ = try? StitchFileManager.createDirectories(at: rootUrl,
                                                         withIntermediate: true)
        await component.encodeDocumentContents(folderUrl: rootUrl)
        
        let url = rootUrl.appendingVersionedSchemaPath()
        await Self.exportComponent(component, url: url)
    }
    
    @Sendable
    static func exportComponent(_ component: Self, url: URL) async {
        do {
            let encodedData = try getStitchEncoder().encode(component)
            try encodedData.write(to: url, options: .atomic)
        } catch {
            fatalErrorIfDebug("exportComponent error: \(error)")
        }
    }
}

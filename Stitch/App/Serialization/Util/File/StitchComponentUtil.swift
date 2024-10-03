//
//  StitchComponentUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/17/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import UniformTypeIdentifiers

extension StitchComponent {
    public var id: UUID {
        get {
            self.graph.id
        }
        
        set(newValue) {
            self.graph.id = newValue
        }
    }
}

extension StitchComponent: StitchComponentable {
    static let zippedFileType: UTType = .stitchComponentZipped
    static let unzippedFileType: UTType = .stitchComponentUnzipped

    /// Builds path given possible nesting inside other components
    var rootUrl: URL {
        let dir = self.saveLocation.getRootDirectoryUrl(componentId: self.id)
        
        return self.isPublished ? dir.appendingComponentPublishedPath() :
        dir.appendingComponentDraftPath()
    }
}

extension StitchComponentable {
    public var id: UUID {
        get {
            self.graph.id
        }
        set(newValue) {
            self.graph.id = newValue
        }
    }
    
    var name: String {
        self.graph.name
    }
    
    var nodes: [NodeEntity] {
        self.graph.nodes
    }
    
    var orderedSidebarLayers: SidebarLayerList {
        self.graph.orderedSidebarLayers
    }
}

extension GraphSaveLocation {
    func getRootDirectoryUrl(componentId: UUID) -> URL {
        switch self {
        case .document(let graphDocumentPath):
            let rootDocPath = StitchDocument.getRootUrl(from: graphDocumentPath.docId)
            
            return graphDocumentPath.componentsPath.reduce(into: rootDocPath) { url, docId in
                url = url
                    .appendingComponentsPath()
                    .appendingPathComponent(docId.uuidString, conformingTo: .stitchComponentUnzipped)
                    .appendingComponentDraftPath()     // Always use draft path
            }
            
            // lastly append with direct parent folders
            .appendingComponentsPath()
            .appendingPathComponent(componentId.uuidString, conformingTo: .stitchComponentUnzipped)
            
        case .userLibrary:
            // TODO: come back to user library
            fatalError()
        }
    }
}
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
        self.saveLocation.getRootDirectoryUrl()
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
    func getRootDirectoryUrl() -> URL {
        switch self {
        case .document(let id):
            return StitchDocument.getRootUrl(from: id)
        
        case .localComponent(let graphDocumentPath):
            let rootDocPath = GraphSaveLocation.document(graphDocumentPath.docId)
                .getRootDirectoryUrl()
            
            return graphDocumentPath.componentsPath.reduce(into: rootDocPath) { url, docId in
                url = url
                    .appendingComponentsPath()
                    .appendingPathComponent(docId.uuidString,
                                            conformingTo: .stitchComponentUnzipped)
            }
            
            // lastly append with direct parent folders
            .appendingComponentsPath()
            .appendingPathComponent(graphDocumentPath.componentId.uuidString,
                                    conformingTo: .stitchComponentUnzipped)
            
        case .systemComponent(let systemType, let componentId):
            return GraphSaveLocation.system(systemType)
                .getRootDirectoryUrl()
                .appendingComponentsPath()
                .appendingPathComponent(componentId.uuidString,
                                        conformingTo: .stitchComponentUnzipped)
        
        case .system(let systemType):
            return StitchFileManager.documentsURL
                .appendingStitchSystemUnzippedPath("\(systemType)")
        }
    }
}

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
    var graphEntity: GraphEntity {
        get {
            self.graph
        }
        set {
            self.graph = newValue
        }
    }
    
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
            self.graphEntity.id
        }
        set(newValue) {
            self.graphEntity.id = newValue
        }
    }
    
    var name: String {
        self.graphEntity.name
    }
    
    var nodes: [NodeEntity] {
        self.graphEntity.nodes
    }
    
    var orderedSidebarLayers: SidebarLayerList {
        self.graphEntity.orderedSidebarLayers
    }
}

extension EncoderDirectoryLocation {
    func getRootDirectoryUrl() -> URL {
        switch self {
        case .document(let graphSaveLocation):
            return graphSaveLocation.getRootDirectoryUrl()
        case .clipboard:
            return StitchClipboardContent.rootUrl
        }
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
    
    var localComponentPath: GraphDocumentPath? {
        switch self {
        case .localComponent(let documentPath):
            return documentPath
        default:
            return nil
        }
    }
}

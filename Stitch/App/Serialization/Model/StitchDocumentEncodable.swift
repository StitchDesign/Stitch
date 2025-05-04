//
//  MediaDocumentEncodable.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/24.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import StitchSchemaKit

protocol StitchDocumentMigratable: Transferable, StitchDocumentEncodable where VersionType.NewestVersionType == Self {
    associatedtype VersionType: StitchSchemaVersionType
    
    static var zippedFileType: UTType { get }
}

extension StitchDocumentMigratable {
    static func getDocument(from url: URL) throws -> Self? {
        guard let doc = try Self.VersionType.migrate(versionedCodableUrl: url) else {
            //                #if DEBUG
            //                fatalError()
            //                #endif
            log("StitchDocumentMigratable.getDocument: could not migrate")
            return nil
        }
        
        return doc
    }
}

protocol StitchDocumentIdentifiable: CustomStringConvertible {
    init()
}

/// Used for `StitchDocument` and `StitchComponent`
protocol StitchDocumentEncodable: Codable, Identifiable where ID: StitchDocumentIdentifiable {
    static var unzippedFileType: UTType { get }
    static var fileWrapper: FileWrapper { get }
    static var subfolders: [StitchEncodableSubfolder] { get }

    init()
    var rootUrl: URL { get }
    var id: ID { get set }
    var name: String { get }
    
    static func getDocument(from url: URL) throws -> Self?
}

enum StitchEncodableSubfolder: String, CaseIterable {
    case media = "ImportedFiles"
    case components = "Components"
}

extension StitchDocumentEncodable {     
    /// Invoked when full path is known.
    func createUnzippedFileWrapper() {
        let folderUrl = self.rootUrl
        Self.createUnzippedFileWrapper(folderUrl: folderUrl)
    }
    
    static func createUnzippedFileWrapper(folderUrl: URL) {
        // Only proceed if folder doesn't exist
        guard !FileManager.default.fileExists(atPath: folderUrl.path) else {
            return
        }

        // Create directory if need be
        let dir = folderUrl.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir,
                                                 withIntermediateDirectories: true)

        do {
            // Create file wrapper which creates the .stitch folder
            try Self.fileWrapper.write(to: folderUrl,
                                       originalContentsURL: nil)
        } catch {
            log("StitchDocumentWrapper.init error: \(error.localizedDescription)")
        }
    }

    static var fileWrapper: FileWrapper {
        FileWrapper(directoryWithFileWrappers: [:])
    }
    
    func encodeNewDocument(srcRootUrl: URL) throws {
        let destRootUrl = self.rootUrl

        try self.installDocument()
        
        // Copy thumbnail if exists
        try? FileManager.default.copyItem(at: srcRootUrl.appendProjectThumbnailPath(),
                                          to: destRootUrl.appendProjectThumbnailPath())
        
        Self.copySubfolders(srcRootUrl: srcRootUrl,
                            destRootUrl: destRootUrl)
    }
    
    func copyProject(documentMutator: (inout Self) -> ()) throws -> Self {
        let srcRootUrl = self.rootUrl
        
        var document = self
        documentMutator(&document)
        
        try document.encodeNewDocument(srcRootUrl: srcRootUrl)
        
        return document
    }
    
    static func copySubfolders(srcRootUrl: URL,
                               destRootUrl: URL) {
        Self.subfolders.forEach { subfolder in
            let subfolderName = subfolder.rawValue
            
            do {
                let srcFolderUrl = srcRootUrl.appendingPathComponent(subfolderName)
                let destFolderUrl = destRootUrl.appendingPathComponent(subfolderName)
                
                guard FileManager.default.fileExists(atPath: srcFolderUrl.path) else {
                    return
                }
                
                try FileManager.default
                    .copyItem(at: srcFolderUrl, to: destFolderUrl)
            } catch {
                log("StitchDocumentEncodable.copySubfolders error: \(error.localizedDescription)")
            }
        }
    }
}

struct StitchDocumentDirectory: Equatable {
    let importedMediaUrls: [URL]
    let componentDirs: [URL]
}

extension StitchDocumentDirectory {
    static var empty: Self {
        self.init(importedMediaUrls: [],
                  componentDirs: [])
    }
    
    var isEmpty: Bool {
        self == .empty
    }
}

struct GraphDecodedFiles {
    let mediaFiles: [URL]
    let components: [StitchComponent]
}

extension [StitchComponent] {
    @MainActor
    func createComponentsDict(parentGraph: GraphState?) -> [UUID: StitchMasterComponent] {
        self.reduce(into: MasterComponentsDict()) { result, componentEntity in
            let newComponent = StitchMasterComponent(componentData: componentEntity,
                                                     parentGraph: nil)  // assigned later
            
            // We can initialize delegates from copy/paste actions
            if let parentGraph = parentGraph {
                newComponent.assignReferences(parentGraph: parentGraph)
            }
            
            result.updateValue(newComponent, forKey: newComponent.id)
        }
    }
}

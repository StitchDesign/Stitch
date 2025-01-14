//
//  StitchDocumentWrapper.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/8/23.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

enum StitchDocumentError: Error {
    case noDataFile
}

extension UTType {
    static let stitchDocument: UTType = UTType(exportedAs: "app.stitchdesign.stitch.document")
    static let stitchProjectData: UTType = UTType(exportedAs: "app.stitchdesign.stitch.projectdata")
    static let stitchSystemZipped: UTType = UTType(exportedAs: "app.stitchdesign.stitch.system")
    static let stitchSystemUnzipped: UTType = UTType(exportedAs: "app.stitchdesign.stitch.systemdata")
    static let stitchComponentZipped: UTType = UTType(exportedAs: "app.stitchdesign.stitch.component")
    static let stitchComponentUnzipped: UTType = UTType(exportedAs: "app.stitchdesign.stitch.componentdata")
    static let stitchClipboard: UTType = UTType(exportedAs: "app.stitchdesign.stitch.clipboard")
    static let stitchJSON: UTType = UTType(exportedAs: "app.stitchdesign.stitch-json-data")
}

extension UUID: StitchDocumentIdentifiable { }

extension StitchDocument: StitchDocumentEncodable, StitchDocumentMigratable {
    typealias VersionType = StitchDocumentVersion
    
    static let unzippedFileType: UTType = .stitchProjectData
    static let zippedFileType: UTType = .stitchDocument
    static let subfolders: [StitchEncodableSubfolder] = StitchEncodableSubfolder.allCases
    
    init() {
        self.init(nodes: [])
    }
    
    static func getRootUrl(from documentId: Self.ID) -> URL {
        StitchFileManager.documentsURL
            .appendingStitchProjectDataPath("\(documentId)")
    }
    
    /// URL location for document contents, i.e. imported media
    var rootUrl: URL {
        Self.getRootUrl(from: self.id)
    }
    
    public var id: ProjectId {
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
    
    init(nodes: [NodeEntity] = []) {
        self.init(graph: .init(id: .init(),
                               name: STITCH_PROJECT_DEFAULT_NAME,
                               migrationWarning: nil,
                               nodes: nodes,
                               orderedSidebarLayers: [],
                               commentBoxes: []),
                  previewWindowSize: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE,
                  previewSizeDevice: PreviewWindowDevice.DEFAULT_PREVIEW_OPTION,
                  previewWindowBackgroundColor: DEFAULT_FLOATING_WINDOW_COLOR,
                  localPosition: ABSOLUTE_GRAPH_CENTER,
                  zoomData: 1,
                  cameraSettings: .init())
    }
    
    static let graphDataFileName = "data"
}

extension StitchDocumentEncodable {
    static func getUniqueInternalDirectoryName(from id: String) -> String {
        Self.getFileName(projectId: id)
    }
    
    static func getFileName(projectId: String) -> String {
        "stitch--\(projectId)"
    }

    /// Creates a file extension given some specific document version.
    static func createDataFileExtension(version: StitchSchemaVersion) -> String {
        let versionString = "v\(version.rawValue)"
        let fileExt = "\(versionString).json"
        return fileExt
    }
}

extension StitchComponent: StitchDocumentMigratable {
    typealias VersionType = StitchComponentVersion
    
    init() {
        self.init(saveLocation: .localComponent(.init(docId: .init(),
                                                      componentId: .init(),
                                                      componentsPath: [])),
                  graph: GraphEntity.createEmpty())
    }
}

extension StitchClipboardContent {
    var name: String {
        self.graph.name
    }
    
    public var id: UUID {
        get {
            self.graph.id
        }
        set(newValue) {
            self.graph.id = newValue
        }
    }
}

extension StitchComponent {
    static func migrateEncodedComponent(from componentUrl: URL) throws -> StitchComponent? {
        let versionedDataUrls = componentUrl.getVersionedDataUrls()
        
        do {
            // If multiple verisoned URLs found, delete the older documents
            guard let graphDataUrl: URL = try versionedDataUrls.getAndCleanupVersions() else {
                log("StitchComponent.migrateEncodedComponents error: could not get versioned URL from package.")
                return nil
            }
            
            return try StitchComponentVersion.migrate(versionedCodableUrl: graphDataUrl)
        } catch {
            fatalErrorIfDebug("StitchDocumentData.openDocument error on components decoding: \(error)")
            return nil
        }
    }
}

extension GraphEntity {
    static func createEmpty() -> Self {
        .init(id: .init(),
              name: "",
              migrationWarning: nil,
              nodes: [],
              orderedSidebarLayers: [],
              commentBoxes: [])
    }
}

extension StitchDocumentMigratable {
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: Self.zippedFileType,
                           exporting: Self.exportDocument,
                           importing: Self.importDocument)
    }
    
    @Sendable
    static func exportDocument(_ document: Self) async -> SentTransferredFile {
        log("StitchDocumentWrapper: transferRepresentation: exporting: called")
        assertInDebug(Self.zippedFileType.preferredFilenameExtension != nil)
        
        let projectURL = document.rootUrl
        let fileNameExt = Self.zippedFileType.preferredFilenameExtension ?? ""
        let tempURLDir = StitchFileManager.exportedFilesDir
        
        /* This is needed because we cna't create files that have "/" characters in them. In order to support that, we have to replace any instane of "/" with ":".
         The file system will handle the conversion for us. See this SO post for details: https://stackoverflow.com/questions/78942602/supporting-custom-files-with-characters-in-swift/78942629#78942629 */
        let exportedFileName = (document.name + "." + fileNameExt).replacingOccurrences(of: "/", with: ":")

        let tempURL = tempURLDir
            .appendingPathComponent(exportedFileName, conformingTo: .stitchDocument)

        log("StitchDocumentWrapper: transferRepresentation: projectURL: \(projectURL)")
        log("StitchDocumentWrapper: transferRepresentation: tempURL: \(tempURL)")

        do {
            // First remove any existing projects at tempURL;
            // Note: it's okay for this to fail when there's no URL already existing there
            try? FileManager.default.removeItem(at: tempURLDir)
            
            // Create exported folder if not yet made
            try? FileManager.default.createDirectory(at: tempURLDir, withIntermediateDirectories: true)

            //            try FileManager.default.createDirectory(at: tempURL,
            //                                                    withIntermediateDirectories: true)

            // zip existing project url's contents to a url
            try FileManager.default.zipItem(at: projectURL, to: tempURL)

            // Create versioned document
            //            try await document.encodeVersionedContents(directoryUrl: StitchFileManager.tempDir)

            // TODO: delete the file from temp-dir after successful export?
            return SentTransferredFile(tempURL)
        } catch {
            // TODO: how to handle a failure here?
            log("StitchDocumentWrapper: transferRepresentation: FAILED: error: \(error)")
            //            fatalError("StitchDocumentWrapper: transferRepresentation: error: \(error)")
            return SentTransferredFile(tempURL)
        }
    }

    @Sendable
    static func importDocument(_ received: ReceivedTransferredFile) async -> Self {
        do {
            guard let data = try await Self.openDocument(from: received.file,
                                                        isImport: true) else {
                //                #if DEBUG
                //                fatalError()
                //                #endif
                DispatchQueue.main.async {
                    dispatch(DisplayError(error: .unsupportedProject))
                }
                return .init()
            }

            return data
        } catch {
            fatalErrorIfDebug()
            return .init()
        }
    }

    static func openDocument(from importedUrl: URL,
                             isImport: Bool = false,
                             isNonICloudDocumentsFile: Bool = false) async throws -> Self? {
        
        // log("openDocument importedUrl: \(importedUrl)")
                
        let _ = importedUrl.startAccessingSecurityScopedResource()
        
        if StitchFileManager.cloudEnabled()
            // `FileManager.default.startDownloadingUbiquitousItem(at:)` is only for iCloud Documents.
            && !isNonICloudDocumentsFile {
            // log("openDocument: attempting startDownloadingUbiquitousItem")
            try? FileManager.default.startDownloadingUbiquitousItem(at: importedUrl)
        }
        
        guard let projectDataUrl = try Self.getUnzippedProjectData(importedUrl: importedUrl) else {
            log("openDocument: could not get unzipped project data")
            return nil
        }

        let versionedDataUrls = projectDataUrl.getVersionedDataUrls()

        // If multiple verisoned URLs found, delete the older documents
        guard let graphDataUrl = try versionedDataUrls.getAndCleanupVersions() else {
            log("StitchDocument.importDocument error: could not get versioned URL from package.")
            throw StitchDocumentError.noDataFile
        }

        // Migrate document content given some URL
        guard var codableDoc = try Self.getDocument(from: graphDataUrl) else {
            log("openDocument: could not migrate")
            return nil
        }

        if isImport {
            // Change ID as to not overwrite possibly existing document
            codableDoc.id = .init()

            // Move imported project contents to application sandbox
            try FileManager.default.moveItem(at: projectDataUrl, to: codableDoc.rootUrl)
            // log("openDocument: successfully moved item")
            
            // Encode document contents on import to save newest project data
            try Self.encodeDocument(codableDoc)
            // log("openDocument: successfully encoded item")
        }
        
        graphDataUrl.stopAccessingSecurityScopedResource()

//        log("openDocument: returning codable doc")
        return codableDoc
    }
}

extension StitchDocumentEncodable {
    /// Unzips document contents on project import, returning the URL of the unzipped contents.
    static func getUnzippedProjectData(importedUrl: URL) throws -> URL? {
        // .stitchproject is already unzipped so we just return this
        if importedUrl.pathExtension == Self.unzippedFileType.preferredFilenameExtension {
            return importedUrl
        }
        
        guard importedUrl.pathExtension == UTType.stitchDocument.preferredFilenameExtension else {
            fatalErrorIfDebug("Expected .stitch file type but got: \(importedUrl.pathExtension)")
            return nil
        }
        
        let unzipDestinationURL = StitchFileManager.importedFilesDir
            .appendingPathComponent(UUID().uuidString)
        
        // Create imported folder if not yet made
        try? FileManager.default.createDirectory(at: unzipDestinationURL, withIntermediateDirectories: true)
        
        try FileManager.default.unzipItem(at: importedUrl, to: unzipDestinationURL)
        
        // Find .stitchproject file
        let items = try FileManager.default.contentsOfDirectory(at: unzipDestinationURL,
                                                                includingPropertiesForKeys: nil)
        let projectFile = items.first { file in
            file.pathExtension == Self.unzippedFileType.preferredFilenameExtension
        }
        
        return projectFile
    }
}

extension StitchDocument {
    public static let defaultName = "Untitled"
    
    /// Matches iPHone 12, 13, 14 etc
    public static let defaultPreviewWindowSize = CGSize(width: 390, height: 844)
    
    public static let defaultBackgroundColor = Color.white
}

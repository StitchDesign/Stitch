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

extension StitchDocument: Identifiable {
    public var id: ProjectId { self.projectId }
}

enum StitchDocumentError: Error {
    case noDataFile
}

extension UTType {
    static let stitchDocument: UTType = UTType(exportedAs: "app.stitchdesign.stitch.document")
    static let stitchProjectData: UTType = UTType(exportedAs: "app.stitchdesign.stitch.projectdata")
    static let stitchComponent: UTType = UTType(exportedAs: "app.stitchdesign.stitch.component")
    static let stitchJSON: UTType = UTType(exportedAs: "app.stitchdesign.stitch-json-data")
}

extension StitchDocument: StitchDocumentIdentifiable {
    init(nodes: [NodeEntity] = []) {
        self.init(projectId: ProjectId(),
                  name: STITCH_PROJECT_DEFAULT_NAME,
                  previewWindowSize: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE,
                  previewSizeDevice: PreviewWindowDevice.DEFAULT_PREVIEW_OPTION,
                  previewWindowBackgroundColor: DEFAULT_FLOATING_WINDOW_COLOR,
                  localPosition: .zero,
                  zoomData: 1,
                  nodes: nodes,
                  orderedSidebarLayers: [],
                  commentBoxes: .init(),
                  cameraSettings: .init())
    }
    
    static let graphDataFileName = "data"
}

extension StitchDocumentIdentifiable {
    var uniqueInternalDirectoryName: String {
        Self.getFileName(projectId: self.projectId)
    }
    
    static func getFileName(projectId: ProjectId) -> String {
        "stitch--\(projectId)"
    }

    /// Creates a file extension given some specific document version.
    static func createDataFileExtension(version: StitchSchemaVersion) -> String {
        let versionString = "v\(version.rawValue)"
        let fileExt = "\(versionString).json"
        return fileExt
    }

    /// URL location for document contents, i.e. imported media
    var rootUrl: URL {
        StitchFileManager.documentsURL
            .url
            .appendingStitchProjectDataPath(self)
    }

    /// URL location for recently deleted project.
    private var recentlyDeletedUrl: URL {
        StitchDocument.recentlyDeletedURL.appendingStitchProjectDataPath(self)
    }

    func getUrl(forRecentlyDeleted: Bool = false) -> URL {
        if forRecentlyDeleted {
            return self.recentlyDeletedUrl
        }
        return self.rootUrl
    }
}

protocol StitchDocumentIdentifiable: MediaDocumentEncodable {
    var projectId: UUID { get }
}

extension StitchDocument: Transferable, Sendable {
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .stitchDocument,
                           exporting: Self.exportDocument,
                           importing: Self.importDocument)
    }

    @Sendable
    static func exportDocument(_ document: StitchDocument) async -> SentTransferredFile {
        log("StitchDocumentWrapper: transferRepresentation: exporting: called")

        let projectURL = document.getUrl()
        
        /* This is needed because we cna't create files that have "/" characters in them. In order to support that, we have to replace any instane of "/" with ":".
         The file system will handle the conversion for us. See this SO post for details: https://stackoverflow.com/questions/78942602/supporting-custom-files-with-characters-in-swift/78942629#78942629 */
        let exportedFileName = (document.name + ".stitch").replacingOccurrences(of: "/", with: ":")

        let tempURL = StitchFileManager.tempDir
            .appendingPathComponent(exportedFileName, conformingTo: .stitchDocument)

        log("StitchDocumentWrapper: transferRepresentation: projectURL: \(projectURL)")
        log("StitchDocumentWrapper: transferRepresentation: tempURL: \(tempURL)")

        do {
            // First remove any existing projects at tempURL;
            // Note: it's okay for this to fail when there's no URL already existing there
            try? FileManager.default.removeItem(at: tempURL)

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
    static func importDocument(_ received: ReceivedTransferredFile) async -> StitchDocument {
        do {
            guard let doc = try await Self.openDocument(from: received.file,
                                                        isImport: true) else {
                //                #if DEBUG
                //                fatalError()
                //                #endif
                DispatchQueue.main.async {
                    dispatch(DisplayError(error: .unsupportedProject))
                }
                return StitchDocument()
            }

            return doc
        } catch {
            fatalErrorIfDebug()
            return StitchDocument()
        }
    }

    static func openDocument(from importedUrl: URL,
                             isImport: Bool = false,
                             isNonICloudDocumentsFile: Bool = false ) async throws -> StitchDocument? {
        
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
        guard var codableDoc = try StitchDocumentVersion.migrate(versionedCodableUrl: graphDataUrl) else {
            //                #if DEBUG
            //                fatalError()
            //                #endif
            log("openDocument: could not migrate")
            return nil
        }

        if isImport {
            // Change ID as to not overwrite possibly existing document
            codableDoc.projectId = .init()

            // Move imported project contents to application sandbox
            try FileManager.default.moveItem(at: projectDataUrl, to: codableDoc.rootUrl)
            // log("openDocument: successfully moved item")
            
            // Encode document contents on import to save newest project data
            try DocumentLoader.encodeDocument(codableDoc)
            // log("openDocument: successfully encoded item")
        }

        graphDataUrl.stopAccessingSecurityScopedResource()

        log("openDocument: returning codable doc")
        return codableDoc
    }
}

extension StitchDocument {
    /// Unzips document contents on project import, returning the URL of the unzipped contents.
    static func getUnzippedProjectData(importedUrl: URL) throws -> URL? {
        // .stitchproject is already unzipped so we just return this
        if importedUrl.pathExtension == UTType.stitchProjectData.preferredFilenameExtension {
            return importedUrl
        }
        
        guard importedUrl.pathExtension == UTType.stitchDocument.preferredFilenameExtension else {
            fatalErrorIfDebug("Expected .stitch file type but got: \(importedUrl.pathExtension)")
            return nil
        }

        let unzipDestinationURL = StitchFileManager.tempDir
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.unzipItem(at: importedUrl, to: unzipDestinationURL)

        // Find .stitchproject file
        let items = try FileManager.default.contentsOfDirectory(at: unzipDestinationURL,
                                                                includingPropertiesForKeys: nil)
        let projectFile = items.first { file in
            file.pathExtension == UTType.stitchProjectData.preferredFilenameExtension
        }

        return projectFile
    }
    
    public static let defaultName = "Untitled"
    
    /// Matches iPHone 12, 13, 14 etc
    public static let defaultPreviewWindowSize = CGSize(width: 390, height: 844)
    
    public static let defaultBackgroundColor = Color.white
}

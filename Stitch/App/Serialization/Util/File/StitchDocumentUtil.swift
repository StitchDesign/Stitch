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
    static let stitchClipboard: UTType = UTType(exportedAs: "app.stitchdesign.stitch.clipboard")
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
                  draftedComponents: [],
                  cameraSettings: .init())
    }
    
    static let graphDataFileName = "data"
}

extension StitchDocumentIdentifiable {
    static func getUniqueInternalDirectoryName(from id: UUID) -> String {
        Self.getFileName(projectId: id)
    }
    
    static func getFileName(projectId: UUID) -> String {
        "stitch--\(projectId)"
    }

    /// Creates a file extension given some specific document version.
    static func createDataFileExtension(version: StitchSchemaVersion) -> String {
        let versionString = "v\(version.rawValue)"
        let fileExt = "\(versionString).json"
        return fileExt
    }
    
    static func getRootUrl(from documentId: UUID) -> URL {
        StitchFileManager.documentsURL
            .url
            .appendingStitchProjectDataPath(documentId)
    }

    /// URL location for document contents, i.e. imported media
    var rootUrl: URL {
        Self.getRootUrl(from: self.projectId)
    }
    
    func getEncodingUrl(documentRootUrl: URL) -> URL {
        // Use param in case going to recently deleted temp directory
        documentRootUrl
    }

    /// URL location for recently deleted project.
    private var recentlyDeletedUrl: URL {
        StitchDocument.recentlyDeletedURL.appendingStitchProjectDataPath(self.projectId)
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

// TODO: move
/// Data structure representing all saved files for some project.
/// Components are not defined in `StitchDocument` as they are managed in separate files.
struct StitchDocumentData: Equatable {
    var document: StitchDocument
    
    // final copies of components--only updated on user publish
    let publishedDocumentComponents: [StitchComponent]
}

extension StitchComponent: MediaDocumentEncodable {
    func getEncodingUrl(documentRootUrl: URL) -> URL {
        documentRootUrl.appendingComponentsPath()
    }
}

extension StitchComponent {
    static func migrateEncodedComponents(at directory: URL) throws -> [StitchComponent] {
        let componentDirectories = try FileManager.default.contentsOfDirectory(atPath: directory.path())
        
        let components = componentDirectories.compactMap { componentPath in
            let componentUrl = URL(fileURLWithPath: componentPath, isDirectory: true)
            do {
                return try StitchComonentVersion.migrate(versionedCodableUrl: componentUrl)
            } catch {
                fatalErrorIfDebug("StitchDocumentData.openDocument error on components decoding: \(error)")
                return nil
            }
        }
        
        return components
    }
}

extension StitchDocumentData: MediaDocumentEncodable {
    func getEncodingUrl(documentRootUrl: URL) -> URL {
        // Don't append anything to parameter
        documentRootUrl
    }
}

extension StitchDocumentData: Transferable, Sendable {
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .stitchDocument,
                           exporting: Self.exportDocument,
                           importing: Self.importDocument)
    }

    @Sendable
    static func exportDocument(_ data: StitchDocumentData) async -> SentTransferredFile {
        log("StitchDocumentWrapper: transferRepresentation: exporting: called")

        let document = data.document
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
    static func importDocument(_ received: ReceivedTransferredFile) async -> StitchDocumentData {
        do {
            guard let data = try await Self.openDocument(from: received.file,
                                                        isImport: true) else {
                //                #if DEBUG
                //                fatalError()
                //                #endif
                DispatchQueue.main.async {
                    dispatch(DisplayError(error: .unsupportedProject))
                }
                return .init(document: .init(),
                             publishedDocumentComponents: [])
            }

            return data
        } catch {
            fatalErrorIfDebug()
            return .init(document: .init(),
                         publishedDocumentComponents: [])
        }
    }

    static func openDocument(from importedUrl: URL,
                             isImport: Bool = false,
                             isNonICloudDocumentsFile: Bool = false ) async throws -> StitchDocumentData? {
        
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
        guard var codableDoc: StitchDocument = try StitchDocumentVersion.migrate(versionedCodableUrl: graphDataUrl) else {
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
            try DocumentLoader.encodeDocument(codableDoc, to: codableDoc.rootUrl)
            // log("openDocument: successfully encoded item")
        }
        
        // Find and migrate each installed component
        let publishedDocumentComponentsDir = codableDoc.componentsDirUrl
        let components = try StitchComponent.migrateEncodedComponents(at: publishedDocumentComponentsDir)

        graphDataUrl.stopAccessingSecurityScopedResource()

        log("openDocument: returning codable doc")
        let data = StitchDocumentData(document: codableDoc,
                                      publishedDocumentComponents: components)
        return data
    }
}

extension StitchDocumentData {
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
}

extension StitchDocument {
    public static let defaultName = "Untitled"
    
    /// Matches iPHone 12, 13, 14 etc
    public static let defaultPreviewWindowSize = CGSize(width: 390, height: 844)
    
    public static let defaultBackgroundColor = Color.white
}

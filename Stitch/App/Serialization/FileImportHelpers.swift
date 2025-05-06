//
//  FileImportHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/6/25.
//

import Foundation
import UniformTypeIdentifiers

// Strong wrapper types to distinguish between the dropped file's URL vs. temporary directory's URL vs. temporary-file's URL
struct TemporaryDirectoryURL: Equatable, Codable, Hashable {
    let value: URL
    
    // Whenever we access the temporary directory,
    // we want to first clear / create it.
    init() {
        let temporaryDirectoryURL: URL = StitchFileManager.importedFilesDir
        
        // Clear previous data
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        
        // Create imported folder if not yet made
        try? FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
        
        self.value = temporaryDirectoryURL
    }
}

struct TemporaryURL: Equatable, Codable, Hashable {
    let value: URL
    
    // Creating a temp-url requires a temporary directory.
    init?(url: URL,
          _ temporaryDirectoryURL: TemporaryDirectoryURL) {
        
        // MARK: due to async logic of dispatched effects, the provided temporary URL has a tendancy to expire, so a new URL is created.
        let tempURL = temporaryDirectoryURL.value
            .appendingPathComponent(url.filename)
            .appendingPathExtension(url.pathExtension)
        
        let _ = url.startAccessingSecurityScopedResource()
        
        // Default FileManager ok here given we just need a temp URL
        do {
            try FileManager.default.copyItem(at: url, to: tempURL)
            url.stopAccessingSecurityScopedResource()
            self.value = tempURL
        } catch {
            url.stopAccessingSecurityScopedResource()
            fatalErrorIfDebug("handleOnDrop error: \(error)")
            return nil
        }
    }
}

extension URL {
    var isStitchDocumentExtension: Bool {
        self.pathExtension == UTType.stitchDocument.preferredFilenameExtension
    }
}


// Used by modal that imports a single sample project;
// prepares the temporary-directory etc.
func importStitchSampleProjectSideEffect(sampleProjectURL: URL,
                                         store: StitchStore) {
        
    guard let tempURL = TemporaryURL(url: sampleProjectURL,
                                     TemporaryDirectoryURL()) else {
        fatalErrorIfDebug()
        return
    }
    
    importStitchProjectSideEffect(tempURL: tempURL, store: store)
}


// ASSUMES WE'VE ALREADY "PREPARED" THE TEMP-DIRECTORY URL AND TEMP-URL
func importStitchProjectSideEffect(tempURL: TemporaryURL,
                                   store: StitchStore) {
    
    guard tempURL.value.isStitchDocumentExtension else {
        fatalErrorIfDebug() // called incorrectly
        return
    }
    
    Task(priority: .high) { [weak store] in
        do {
            switch await store?.documentLoader.loadDocument(from: tempURL.value,
                                                            isImport: true) {
                
            case .loaded(let data, _):
                await store?.createNewProjectSideEffect(from: data, isProjectImport: true)
                
            default:
                DispatchQueue.main.async {
                    dispatch(DisplayError(error: .unsupportedProject))
                }
                return
            }
        }
    }
}

func importMediaFileToStitch(tempURL: TemporaryURL) {
    let _ = tempURL.value.startAccessingSecurityScopedResource()
    DispatchQueue.main.async {
        dispatch(ImportFileToNewNode(url: tempURL.value))
    }
    tempURL.value.stopAccessingSecurityScopedResource()
}


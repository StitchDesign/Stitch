//
//  StitchFileError.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation

enum StitchFileError: Error {
    // Imported file contains a version newer than what's supported at runtime
    case unsupportedProject
    // Data couldn't be serialized to JSON
    case serializationFailed
    // FileManager failed to read contents in documents directory
    case documentsDirUnreadable
    // Download failed after multiple retries
    case downloadFailed
    // The file could not copy
    case copyFileFailed
    // The file could not be replaced
    case replaceItemFailed
    // File deletion failed
    case deleteFileFailed
    // Write op failed
    case projectWriteFailed
    // iCloud docs couldn't be synced
    case cloudDownloadFailed(_ error: Error)
    // Failed to retrieve URL for iCloud docs container
    case cloudDocsContainerNotFound
    // Couldn't create zip for sharing
    case zipFailed(_ error: Error)
    // Couldn't unzip file from a shared project
    case unzipFailed
    // Found an incorrect number of URLs after unzipping project
    case incorrectUrlCountInZip(count: Int)
    // File import failed for some media
    case mediaFilesImportFailed(_ error: String)
    // Imported file is an unsupported file type
    case mediaFileUnsupported(_ fileExt: String)
    // Node doesn't support imported media
    case mediaFileUnsupportedForNode(fileExt: String)
    // Couldn't find URL from a dropped media file
    case droppedMediaFileFailed
    // Couldn't find media in Library state
    case mediaNotFoundInLibrary
    // Couldn't find media in media manager
    case mediaNotFoundInMediaManager
    // Unable to create imageDeps from image
    case imageProcessingFailed(_ filename: String)
    // Unable to copy some image
    case imageCloneFailed
    // Unable to decode graph schema
    case graphSchemaNotFound
    // Intemediary directories could not be created for the project
    case docsDirCreationFailed
    // Project schema couldn't be found in AppState
    case projectSchemaNotFound
    // Unable to create data object from URL
    case dataFromUrlFailed
    // Failed to decode an object
    case decodingFailed
    // Failed to convert Data to JSON
    case dataToJsonFailed
    // Unable to locate a default component
    case defaultComponentNotFound
    // Unable to locate sample project from quick start menu
    case sampleAppNotFound
    // Unable to decode any projects from samples list
    case noSampleAppsDecoded
    // We expected to find a `currentProject` in state but none was found
    case currentProjectNotFound
    // Encoding failed for VersionableContainer
    case versionableContainerEncodingFailed
    // Unable to locate node in GraphState
    case nodeNotFound
    // New file couldn't be created from established sample range
    case trimMediaFileFailed
    // User already declined camera permissions despite creating camera node
    case cameraPermissionDeclined
    // Error received getting camera info
    case getCameraDeviceInfoFailed
    // Failed to initialize 3D Scene
    case failedToCreate3DScene
    // Failed to copy media to a directory
    case mediaCopiedFailed
    // Failed to create media object from URL
    case mediaCreationFromURLFailed
    // Conversion from base64 to image failed
    case base64ToImgFailed
    // Conversion from image to base64 failed
    case imgToBase64Failed
    // Conversion from CanvasDrawingView(lines) to UIImage of that SwiftUIView failed
    case canvasSketchImageRenderingFailed
    // Some port id numbers changed, so we threw away some old edges
    case edgesLostDuringMigration
    // Failed to apply grayscale to UIImage
    case imageGrayscaleFailed
    // Failed to obtain file metadata for some project URL
    case projectMetadataFailed
    // ID not passed in for media object when 3D model was expected
    case idNotFoundFor3DModel
    // Prompts user to enable recording
    case recordingPermissionsDisabled
    // Project duplication
    case projectDuplicationFailed
    // Unexpected error
    case unknownError(_ message: String)
}

extension StitchFileError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unsupportedProject:
            return "Stitch needs to be updated to open this project."
        case .serializationFailed:
            return "Stitch was unable to save the project (JSON serialization error)."
        case .documentsDirUnreadable:
            return "Stitch was unable to read contents in the Documents directory."
        case .downloadFailed:
            return "Stitch failed to download the project"
        case .copyFileFailed, .replaceItemFailed:
            return "Stitch failed copying to the project."
        case .deleteFileFailed:
            return "Stitch failed deleting the project."
        case .projectWriteFailed:
            return "Stitch was unable to save the project (project write failure)."
        case .cloudDownloadFailed:
            return "Stitch was unable to sync projects from the cloud."
        case .cloudDocsContainerNotFound:
            return "Stitch was unable to locate the iCloud Documents container."
        case .zipFailed:
            return "Stitch was unable to share the project. Please try again."
        case .unzipFailed:
            return "Stitch was unable to import the project. The contents may have been corrupted."
        case .incorrectUrlCountInZip:
            return "Stitch found a problem opening the project. The contents may have been modified."
        case .mediaFilesImportFailed(let error):
            return "Error importing files. \(error)"
        case .mediaFileUnsupported(let fileExt):
            return "Stitch doesn't support importing .\(fileExt) media."
        case .mediaFileUnsupportedForNode(let fileExt):
            return "Stitch doesn't support .\(fileExt) files with this node."
        case .droppedMediaFileFailed:
            return "Stitch was unable to import this file."
        case .mediaNotFoundInLibrary:
            return "Stitch encountered an error loading the selected media."
        case .mediaNotFoundInMediaManager:
            return "Stitch encountered an error finding the selected media."
        case .imageProcessingFailed(let filename):
            return "Unable to process image \(filename)"
        case .imageCloneFailed:
            return "There was an issue processing your image."
        case .graphSchemaNotFound:
            return "Something went wrong with the project's data."
        case .docsDirCreationFailed:
            return "Stitch was unable to create the directories needed to save this project."
        case .projectSchemaNotFound:
            return "Stitch was unable to find the project to save to."
        case .dataFromUrlFailed:
            return "Stitch was unable to read one of your project files."
        case .decodingFailed, .dataToJsonFailed:
            return "Stitch encountered a problem opening your project."
        case .defaultComponentNotFound:
            return "Stitch was unable to locate the default component."
        case .sampleAppNotFound:
            return "Stitch was unable to locate the sample app."
        case .noSampleAppsDecoded:
            return "Stitch was unable to load sample documents. Sorry about this!"
        case .currentProjectNotFound:
            return "Stitch encountered an error locating the current project."
        case .versionableContainerEncodingFailed:
            return "Error: unable to read project file."
        case .nodeNotFound:
            return "Stitch was unable to update the node."
        case .trimMediaFileFailed:
            return "The sample range could not be created, please try again."
        case .cameraPermissionDeclined:
            return "The camera could not be enabled due to disabled camera permissions. Enable the camera by accessing the Settings app -> Stitch -> Camera."
        case .getCameraDeviceInfoFailed:
            return "Error: no camera found."
        case .unknownError(let message):
            return "Stitch encountered a problem: \(message)"
        case .mediaCopiedFailed:
            return "Stitch was unable to create a copy of the media file."
        case .mediaCreationFromURLFailed:
            return "Stitch was unable to create the media object."
        case .base64ToImgFailed:
            return "Stitch was unable to convert a Base64 string to an image."
        case .imgToBase64Failed:
            return "Stitch was unable to convert an image to a Base64 string."
        case .canvasSketchImageRenderingFailed:
            return "Failed to create an image of the canvas drawing."
        case .failedToCreate3DScene:
            return "Failed to initialize 3D Scene."
        case .edgesLostDuringMigration:
            return "Some graph edges were lost during project migration."
        case .imageGrayscaleFailed:
            return "There was an issue applying grayscale to your image."
        case .projectMetadataFailed:
            return "Your project file was corrupted."
        case .idNotFoundFor3DModel:
            return "There was an issue creating your 3D model."
        case .recordingPermissionsDisabled:
            return "This project requires Stitch to access your microphone."
        case .projectDuplicationFailed:
            return "Stitch was unable to duplicate this project."
        }
    }

    var showSettingsPrompt: Bool {
        switch self {
        case .recordingPermissionsDisabled:
            return true
        default:
            return false
        }
    }
}

extension StitchFileError: Equatable {
    static func == (lhs: StitchFileError, rhs: StitchFileError) -> Bool {
        // Not ideal but necessary to make StitchFileError equatable (somehow) in AppState
        lhs.description == rhs.description
    }
}

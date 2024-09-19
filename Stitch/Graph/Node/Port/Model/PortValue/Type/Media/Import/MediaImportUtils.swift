//
//  MediaImportUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

extension GraphDelegate {
    func createMediaObject(mediaKey: MediaKey,
                           nodeId: NodeId?,
                           url: URL?) async -> StitchFileResult<StitchMediaObject> {
        guard let url = url else {
            // Check temp storage before failing
            switch await self.undoDeletedMedia(mediaKey: mediaKey) {
            case .success(let url):
                await MainActor.run { [weak self] in
                    let _ = self?.mediaLibrary.updateValue(url, forKey: mediaKey)
                }
                return await url.createMediaObject(nodeId: nodeId)

            case .failure(let error):
                log("MediaKey.createMediaObject error: \(error)")
                return .failure(.mediaNotFoundInLibrary)
            }
        }

        return await url.createMediaObject(nodeId: nodeId)
    }
}

extension URL {
    /// Creates media object. ID only needed for 3D model object.
    func createMediaObject(nodeId: NodeId?) async -> MediaObjectResult {
        let pathExtension = self.pathExtension.uppercased()

        if isImageFile(pathExtension: pathExtension) {
            guard let data = try? Data(contentsOf: self),
                  let uiImage = UIImage(data: data) else {
                return .failure(.mediaCreationFromURLFailed)
            }

            // Provides the ability to assign some name
            uiImage.accessibilityIdentifier = self.filename

            return .success(.image(uiImage))
        }
        if isVideoFile(pathExtension: pathExtension) {
            let videoPlayer = await StitchVideoImportPlayer(url: self,
                                                            videoData: VideoMetadata(),
                                                            initialVolume: StitchVideoImportPlayer.DEFAULT_VIDEO_PLAYER_VOLUME)
            return .success(.video(videoPlayer))
        }
        if isSoundFile(pathExtension: pathExtension) {
            let soundPlayer = await MainActor.run {
                let soundFilePlayer = StitchSoundFilePlayer(url: self)
                return StitchSoundPlayer(delegate: soundFilePlayer)
            }
            return .success(.soundfile(soundPlayer))
        }
        if isMlModelFile(pathExtension: pathExtension) {

            do {
                let model = try StitchMLModel(
                    originalURL: self)
                return .success(.coreMLImageModel(model))
            } catch {
                log("CoreMLDeps error: \(error.localizedDescription).")
                return .failure(.mediaFilesImportFailed(error.localizedDescription))
            }
        }
        if isModel3DFile(pathExtension: pathExtension) {
            guard let nodeId = nodeId else {
                fatalErrorIfDebug()
                return .failure(.idNotFoundFor3DModel)
            }
            
            let entity = await StitchEntity(id: .init(),
                                            nodeId: nodeId,
                                            sourceURL: self,
                                            isAnimating: false)
            return .success(.model3D(entity))
        }

        return .failure(.mediaFileUnsupported(pathExtension))
    }
}


/// Helper which determines unique file name out of an already-parsed list.
func createUniqueFilename(filename: String,
                          existingFilenames: [String],
                          mediaType: SupportedMediaFormat) -> String {
    var existingFilenames = existingFilenames

    // Prevent imported file from using same name as other options in dropdown
    existingFilenames += getReservedImportLabels(for: mediaType)

    // Create loop that determines a unique filemane for ImportedFilesURL
    var candidateName = filename
    var incrementor = 1
    while existingFilenames.contains(candidateName) {
        incrementor += 1
        candidateName = "\(filename)\(incrementor)"
    }

    return candidateName
}

/// Obtains list of resersved names for imported media to prevent occurence of duplicate labels in a node's import dropdown.
func getReservedImportLabels(for mediaType: SupportedMediaFormat) -> [String] {
    // Imported media cannot use the name "import", which is reserved for the import
    // button in media nodes. String matching prevents us from using the same name.
    let importLabel = IMPORT_BUTTON_DISPLAY

    switch mediaType {
    case .image:
        return [importLabel, MEDIA_EMPTY_NAME]
    default:
        // TODO: other types
        return [importLabel]
    }
}

let textFileFormats: Set<String> = Set(["TXT"])

func isTextFile(url: URL) -> Bool {
    textFileFormats.contains(url.pathExtension)
}

// Nonexhaustive?: https://stackoverflow.com/questions/29644168/get-image-file-type-programmatically-in-swift
let imageFileFormats: Set<String> = Set(["JPG", "PNG", "JPEG", "HEIC", "TIF", "GIF", "HEIX", "HEVC", "HEVX", "SVG", "WEBP"])

func isImageFile(pathExtension: String) -> Bool {
    imageFileFormats.contains(pathExtension.uppercased())
}

let videoFileFormats: Set<String> = Set(["MOV", "MP4", "AVI"])

func isVideoFile(pathExtension: String) -> Bool {
    videoFileFormats.contains(pathExtension.uppercased())
}

let soundFileFormats: Set<String> = Set(["M4A", "MP3", "CAF"])

func isSoundFile(pathExtension: String) -> Bool {
    soundFileFormats.contains(pathExtension.uppercased())
}

let mlModelFileFormats: Set<String> = Set(["MLMODEL", "MLMODELC"])

func isMlModelFile(pathExtension: String) -> Bool {
    mlModelFileFormats.contains((pathExtension.uppercased()))
}

let model3DFileFormats: Set<String> = Set(["USDZ"])

func isModel3DFile(pathExtension: String) -> Bool {
    model3DFileFormats.contains((pathExtension.uppercased()))
}

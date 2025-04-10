//
//  SupportedMediaFormat.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/11/24.
//

import AVFoundation
import Foundation
import StitchSchemaKit

/// List of file types Stitch supports for import
enum SupportedMediaFormat: String, Codable, Equatable, CaseIterable {
    case image
    case video
    case audio
    case coreML
    case model3D
}

extension SupportedMediaFormat {
    var isVisualMedia: Bool {
        self == .image || self == .video
    }

    var avMediaType: AVMediaType? {
        switch self {
        case .video:
            return AVMediaType.video
        case .audio:
            return AVMediaType.audio
        default:
            // unsupported
            return nil
        }
    }

    static func findType(by pathExtension: String) -> Self? {
        let pathExtension = pathExtension.uppercased()

        if isImageFile(pathExtension: pathExtension) {
            return .image
        }
        if isVideoFile(pathExtension: pathExtension) {
            return .video
        }
        if isSoundFile(pathExtension: pathExtension) {
            return .audio
        }
        if isMlModelFile(pathExtension: pathExtension) {
            return .coreML
        }
        if isModel3DFile(pathExtension: pathExtension) {
            return .model3D
        }

        return nil
    }

    var nodeKind: NodeKind {
        switch self {
        case .image:
            return .patch(.imageImport)
        case .video:
            return .patch(.videoImport)
        case .audio:
            return .patch(.soundImport)
        case .coreML:
            return .patch(.coreMLClassify)
        case .model3D:
            return .layer(.model3D)
        }
    }
}

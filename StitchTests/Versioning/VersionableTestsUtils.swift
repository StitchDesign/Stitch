//
//  VersionableTestsUtils.swift
//  prototypeTests
//
//  Created by Elliot Boschwitz on 4/26/22.
//

// Suite of tools taken from https://github.com/krzysztofzablocki/Versionable

import Foundation
import SwiftUI
@testable import Stitch

// struct Simple {
//    let text: String
//    var version: Version = Self.version
// }
//
// extension Simple: Versionable {
//    enum Version: Int, VersionType {
//        case v1 = 1
//    }
//
//    static func migrate(to: Version) -> Migration {
//        switch to {
//        case .v1:
//            return .none
//        }
//    }
//
//    static var mock: Simple {
//        .init(text: "mock")
//    }
// }
//
// struct Complex {
//    let text: String
//    let number: Int
//    var version: Version = Self.version
// }
//
// extension Complex: Versionable {
//    enum Version: Int, VersionType {
//        case v1 = 1
//        case v2 = 2
//        case v3 = 3
//    }
//
//    static func migrate(to: Version) -> Migration {
//        switch to {
//        case .v1:
//            return .none
//        case .v2:
//            return .migrate { payload in
//                payload["text"] = "defaultText"
//                return .success(payload)
//            }
//        case .v3:
//            return .migrate { payload in
//                payload["number"] = (payload["text"] as? String) == "defaultText" ? 1 : 200
//                return .success(payload)
//            }
//        }
//    }
//
//    static var mock: Complex {
//        .init(text: "mock", number: 0)
//    }
// }
//
// enum SampleTestApp: String {
//    case CameraApp = "Camera App"
//    case UnsupportedApp = "Unsupported Version"
//    case LayerNodes = "Layer Nodes"
//    case PatchNodes = "Patch Nodes"
//    case EarthVideo = "Earth Video"
// }
//
///// Decodes project schema given a URL for a test sample app.
// func importProject(from sampleApp: SampleTestApp,
//                   fileManager: StitchFileManager = StitchFileManager()) async -> ProjectSchemaResult {
//    // Unzip the selected sample app
//    switch getProjectURLFromBundle(resource: sampleApp.rawValue,
//                                   bundle: getTestBundle()) {
//    case .success(let sampleAppUrl):
//        return await fileManager.saveImportedProject(sampleAppUrl.url, documentsURL: fileManager.documentsURL)
//    case .failure(let error):
//        fatalError("loadSampleApp url error: \(error)")
//    }
// }
//
///// Checks if graph schema exists in project schema. Used for unit tests.
// func getGraphSchema(from projectSchema: ProjectSchema) throws -> GraphSchema {
//    guard let graphSchema = projectSchema.schema else {
//        throw StitchFileError.unknownError("No graph schema found in project: \(projectSchema)")
//    }
//    return graphSchema
// }
